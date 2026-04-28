import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/supabase_service.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

class PlanificarViajeWidget extends StatefulWidget {
  const PlanificarViajeWidget({super.key});

  static String routeName = 'PlanificarViaje';
  static String routePath = '/planificarViaje';

  @override
  State<PlanificarViajeWidget> createState() => _PlanificarViajeWidgetState();
}

class _PlanificarViajeWidgetState extends State<PlanificarViajeWidget> {
  final _descripcionController = TextEditingController();
  final _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _necesidades = [];
  List<Map<String, dynamic>> _filteredNecesidades = [];
  List<Map<String, dynamic>> _selectedNecesidades = [];
  List<Map<String, dynamic>> _vehiculos = [];
  List<Map<String, dynamic>> _choferes = [];
  
  Map<String, dynamic>? _selectedVehiculo;
  Map<String, dynamic>? _selectedChofer;
  DateTime _fechaPlanificada = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_filterNecesidades);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final service = SupabaseService();
      final necData = await service.getNecesidadesPendientes();
      final vehData = await service.getVehiculos();
      final choData = await service.getChoferes();

      if (mounted) {
        setState(() {
          _necesidades = necData;
          _filteredNecesidades = necData;
          _vehiculos = vehData;
          _choferes = choData;
          _loading = false;
        });
      }
    } catch (e) {
      print('PlanificarViaje: Error en _fetchData: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterNecesidades() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredNecesidades = _necesidades.where((n) {
        final apicultor = (n['apicultores']?['nombre'] ?? '').toString().toLowerCase();
        final localidad = (n['apicultores']?['localidad'] ?? '').toString().toLowerCase();
        final tipo = (n['tipo'] ?? '').toString().toLowerCase();
        return apicultor.contains(query) || localidad.contains(query) || tipo.contains(query);
      }).toList();
    });
  }

  double get _totalKg => _selectedNecesidades.fold(0.0, (sum, item) => sum + (item['cantidad'] ?? 0).toDouble());
  int get _totalTambores {
    int total = 0;
    for (final n in _selectedNecesidades) {
      if (n['producto'] == 'Miel' || n['tipo'] == 'Recolección') {
        final num cant = n['cantidad'] ?? 0;
        total += (cant / 300).ceil();
      }
    }
    return total;
  }

  bool get _excedeCapacidad {
    if (_selectedVehiculo == null) return false;
    final capKg = (_selectedVehiculo!['capacidad_kg'] ?? 0).toDouble();
    final capTambores = (_selectedVehiculo!['capacidad_tambores'] ?? 0);
    if (capKg > 0 && _totalKg > capKg) return true;
    if (capTambores > 0 && _totalTambores > capTambores) return true;
    return false;
  }

  Future<void> _crearViaje() async {
    if (_selectedVehiculo == null || _selectedChofer == null || _selectedNecesidades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete todos los campos y seleccione necesidades')));
      return;
    }
    if (_excedeCapacidad) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: La carga excede la capacidad del vehículo'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _saving = true);
    try {
      await SupabaseService().createViajeCompleto(
        viajeData: {
          'chofer_id': _selectedChofer!['id'],
          'vehiculo_codigo': _selectedVehiculo!['vehiculo_codigo'],
          'viaje_codigo': 'VIAJE-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
          'estado': 'Planificado',
          'fecha': _fechaPlanificada.toIso8601String(),
          'descripcion': _descripcionController.text,
        },
        necesidades: _selectedNecesidades,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ruta planificada con éxito'), backgroundColor: Colors.green));
        context.pop();
      }
    } catch (e) {
      print('PlanificarViaje: Error al crear viaje: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F8),
        title: const Text('Planificador de Ruta', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, color: Color(0xFF08201A))),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF08201A)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección Necesidades
            const Text('1. Seleccionar Solicitudes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF08201A))),
            const SizedBox(height: 12),
            
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por apicultor, localidad o tipo...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1)),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: _filteredNecesidades.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final n = _filteredNecesidades[index];
                  final isSelected = _selectedNecesidades.any((element) => element['id'] == n['id']);
                  return CheckboxListTile(
                    value: isSelected,
                    title: Text('${n['tipo']} - ${n['apicultores']?['nombre']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('${n['cantidad']} Kg • ${n['apicultores']?['localidad']}'),
                    onChanged: (val) {
                      setState(() {
                        if (val!) {
                          _selectedNecesidades.add(n);
                        } else {
                          _selectedNecesidades.removeWhere((element) => element['id'] == n['id']);
                        }
                      });
                    },
                    activeColor: const Color(0xFF08201A),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Resumen de Carga
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _excedeCapacidad ? const Color(0xFFFFEBEE) : const Color(0xFFF0F4F3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _excedeCapacidad ? Colors.red.withOpacity(0.3) : const Color(0xFF08201A).withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Kg:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${_totalKg.toStringAsFixed(1)} Kg / ${_selectedVehiculo?['capacidad_kg'] ?? '—'} Kg', 
                        style: TextStyle(color: _excedeCapacidad ? Colors.red : Colors.black, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tambores:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('$_totalTambores / ${_selectedVehiculo?['capacidad_tambores'] ?? '—'}', 
                        style: TextStyle(color: _excedeCapacidad ? Colors.red : Colors.black, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (_selectedNecesidades.isNotEmpty) ...[
                    const Divider(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final destinations = _selectedNecesidades
                              .map((n) => n['apicultores']?['localidad'])
                              .where((l) => l != null)
                              .toList();
                          if (destinations.isEmpty) return;
                          
                          String origin = destinations.first;
                          String waypoints = destinations.length > 1 
                              ? destinations.sublist(1).join('|')
                              : '';
                          
                          final url = 'https://www.google.com/maps/dir/?api=1&origin=${Uri.encodeComponent(origin)}&destination=${Uri.encodeComponent(destinations.last)}&waypoints=${Uri.encodeComponent(waypoints)}&travelmode=driving';
                          
                          if (await canLaunchUrlString(url)) {
                            await launchUrlString(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.map_rounded),
                        label: const Text('VER NODOS EN MAPA'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF08201A),
                          side: const BorderSide(color: Color(0xFF08201A)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Selección de Vehículo y Chofer
            const Text('2. Logística', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF08201A))),
            const SizedBox(height: 12),
            
            _buildDropdown<String>(
              label: 'Vehículo',
              hint: 'Seleccione un vehículo...',
              value: _selectedVehiculo?['id']?.toString(),
              items: _vehiculos.map((v) => DropdownMenuItem(
                value: v['id'].toString(),
                child: Text('${v['vehiculo_codigo']} (Max: ${v['capacidad_kg']}Kg / ${v['capacidad_tambores']}T)'),
              )).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedVehiculo = _vehiculos.firstWhere((element) => element['id'].toString() == v);
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            _buildDropdown<String>(
              label: 'Chofer',
              hint: 'Seleccione un chofer...',
              value: _selectedChofer?['id']?.toString(),
              items: _choferes.map((c) => DropdownMenuItem(
                value: c['id'].toString(),
                child: Text('${c['nombre']} ${c['apellido']}'),
              )).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedChofer = _choferes.firstWhere((element) => element['id'].toString() == v);
                });
              },
            ),

            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saving ? null : _crearViaje,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDBE49),
                  foregroundColor: const Color(0xFF08201A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _saving 
                  ? const CircularProgressIndicator(color: Color(0xFF08201A))
                  : const Text('PLANIFICAR RUTA FINAL', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({required String label, String? hint, T? value, required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              hint: hint != null ? Text(hint, style: const TextStyle(fontSize: 14, color: Colors.black45)) : null,
              value: value,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
