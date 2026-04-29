import '../flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase_service.dart';
import 'package:intl/intl.dart';

class ViajeDetalleWidget extends StatefulWidget {
  final String? viajeId;
  const ViajeDetalleWidget({super.key, this.viajeId});

  static String routeName = 'ViajeDetalle';
  static String routePath = '/viajedetalle';

  @override
  State<ViajeDetalleWidget> createState() => _ViajeDetalleWidgetState();
}

class _ViajeDetalleWidgetState extends State<ViajeDetalleWidget> {
  Map<String, dynamic>? _viaje;
  List<Map<String, dynamic>> _paradas = [];
  bool _loading = true;
  String? _error;
  String? _userRole;

  // Stitch colors
  static const kPrimary = Color(0xFF08201A);
  static const kPrimaryContainer = Color(0xFF1E352F);
  static const kSecContainer = Color(0xFFFDBE49);
  static const kSurface = Color(0xFFFBF9F8);
  static const kSurfaceLow = Color(0xFFF5F3F3);
  static const kOnSurface = Color(0xFF1B1C1C);
  static const kOnSurfaceVariant = Color(0xFF424846);
  static const kOutlineVariant = Color(0xFFC2C8C4);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      _userRole = prefs.getString('user_puesto');
      
      if (widget.viajeId != null && widget.viajeId!.isNotEmpty) {
        final data = await SupabaseService().getViajeDetalle(widget.viajeId!);
        
        if (data == null) {
          if (mounted) setState(() { _error = 'Viaje no encontrado'; _loading = false; });
          return;
        }

        if (mounted) {
          setState(() {
            _viaje = data;
            _paradas = List<Map<String, dynamic>>.from(data['paradas'] ?? []);
            _paradas.sort((a, b) => (a['orden_secuencia'] ?? 0).compareTo(b['orden_secuencia'] ?? 0));
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() { _error = 'ID de viaje no válido'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _cambiarEstado(String nuevoEstado) async {
    if (widget.viajeId == null || widget.viajeId!.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('viajes').update({'estado': nuevoEstado})
          .eq('id', widget.viajeId!);
      await _fetchData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _openMaps(String localidad) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(localidad)}';
    if (await canLaunchUrlString(url)) await launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _editViaje() async {
    // Navigate to planificarViaje with current trip data (Mock navigation for now)
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Función de edición en desarrollo')));
  }

  Future<void> _deleteViaje() async {
    final estado = _viaje?['estado'];
    if (!_isAdmin()) return;
    
    // Check permissions: Admins can delete if Planificado. 
    // "Solo el administrador puede eliminar viajes terminados o en proceso."
    // (Assuming user role check already passed _isAdmin)

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Viaje?'),
        content: Text('Esta acción no se puede deshacer. Estado actual: $estado'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ELIMINAR', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('viajes').delete().eq('id', widget.viajeId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viaje eliminado')));
          context.pop();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _openFullItinerary() async {
    if (_paradas.isEmpty) return;
    final localities = _paradas
        .map((p) => p['localidad']?.toString() ?? '')
        .where((l) => l.isNotEmpty)
        .toList();
    
    if (localities.isEmpty) return;
    
    final String destination = localities.last;
    final String waypoints = localities.length > 1 
        ? localities.sublist(0, localities.length - 1).join('|')
        : '';
    
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}&waypoints=${Uri.encodeComponent(waypoints)}&travelmode=driving';
    
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }

  double _calcCargaKg() {
    double total = 0;
    for (final p in _paradas) {
      if (p['bruto_kg'] != null) {
        total += (p['bruto_kg'] as num).toDouble();
      } else {
        final items = p['parada_items'] as List? ?? [];
        for (final item in items) {
          final kg = double.tryParse(item['peso_kg']?.toString() ?? '') ?? 0;
          final qty = (item['cantidad'] as num?)?.toDouble() ?? 1;
          if (kg > 0) total += kg * qty;
        }
      }
    }
    return total;
  }

  bool _isDriver() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final choferId = _viaje?['chofer_id']?.toString();
    return (currentUserId == choferId);
  }

  bool _isAdmin() {
    final role = _userRole?.toUpperCase() ?? '';
    return (role == 'CEO' || role == 'GERENTE' || role == 'GERENCIA' || role == 'ADMIN' || role == 'COMPRAS');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: kSecContainer)));
    if (_error != null) return Scaffold(body: Center(child: Text('Error: $_error')));

    final estado = _viaje?['estado'] ?? 'Planificado';
    final vehiculo = _viaje?['vehiculo_codigo'] ?? 'Sin vehículo';
    final viajeCode = _viaje?['viaje_codigo'] ?? '';
    final fechaRaw = _viaje?['fecha'] ?? _viaje?['created_at'];
    final fecha = DateTime.tryParse(fechaRaw.toString());
    final fechaStr = fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) : 'S/D';
    
    final capacidadMax = 10000.0;
    final cargaActual = _calcCargaKg();
    final progress = (cargaActual / capacidadMax).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        title: Text('Viaje: $viajeCode', style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kPrimary), onPressed: () => context.pop()),
        actions: [
          _statusChip(estado),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Resumen de Viaje
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('FECHA PLANIFICADA', style: TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.bold)),
                          Text(fechaStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('VEHÍCULO', style: TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.bold)),
                          Text(vehiculo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('CARGA ACTUAL', style: TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: progress, backgroundColor: kSurfaceLow, color: kSecContainer, minHeight: 8),
                  const SizedBox(height: 4),
                  Text('${cargaActual.round()} kg / ${capacidadMax.round()} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // Botón Mapa Completo
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openFullItinerary,
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('VER RECORRIDO Y NODOS EN MAPA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryContainer,
                        foregroundColor: kSecContainer,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            
            // Botones de Acción Admin (Editar / Eliminar)
            if (_isAdmin())
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editViaje(),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('EDITAR VIAJE'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kPrimary,
                          side: const BorderSide(color: kPrimary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteViaje(),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('ELIMINAR'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Botones de Acción Chofer (Iniciar / Finalizar)
            if (estado != 'Terminado' && _isDriver())
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _cambiarEstado(estado == 'Planificado' ? 'En Curso' : 'Terminado'),
                    style: ElevatedButton.styleFrom(backgroundColor: kSecContainer, foregroundColor: kPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(estado == 'Planificado' ? 'INICIAR VIAJE' : 'FINALIZAR VIAJE', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              )
            else if (estado != 'Terminado' && !_isAdmin())
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.black38),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Solo el chofer asignado puede cambiar el estado del viaje.',
                          style: TextStyle(fontSize: 12, color: Colors.black45, fontFamily: 'Inter'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Lista de Paradas
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(alignment: Alignment.centerLeft, child: Text('HOJA DE RUTA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _paradas.length,
              itemBuilder: (context, index) {
                final p = _paradas[index];
                final isCompletada = p['estado'] == 'Completada';
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isCompletada ? Colors.green.withOpacity(0.3) : Colors.black12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCompletada ? Colors.green : kPrimaryContainer,
                      child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(p['persona_nombre'] ?? 'Parada', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${p['localidad'] ?? ''}\n${p['tipo_operacion'] ?? ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/paradaDetalle?paradaId=${p['id']}'),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String estado) {
    Color color = Colors.blue;
    if (estado == 'En Curso') color = Colors.orange;
    if (estado == 'Terminado') color = Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(estado.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
