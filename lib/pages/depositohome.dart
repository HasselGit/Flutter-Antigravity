import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../backend/supabase_service.dart';
import '../backend/app_states.dart';
import '../backend/design_tokens.dart';

class DepositohomeWidget extends StatefulWidget {
  const DepositohomeWidget({super.key});

  @override
  State<DepositohomeWidget> createState() => _DepositohomeWidgetState();
}

class _DepositohomeWidgetState extends State<DepositohomeWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _viajesPlanificados = [];
  List<Map<String, dynamic>> _cargasTerminadas = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  bool _loading = true;
  String _searchQuery = '';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      // Fetch Pending Voyages for first tab
      final pendingViajes = await Supabase.instance.client
          .from('viajes')
          .select('*, profiles(nombre, apellido), paradas(*, parada_items(*)), vehiculos:vehiculo_codigo(capacidad_kg, capacidad_tambores)')
          .or('estado.eq.Planificado,estado.eq.Pendiente')
          .order('fecha', ascending: true);

      // Fetch Terminated Cargas for second tab
      final history = await SupabaseService().getTerminatedCargas();

      if (mounted) {
        setState(() {
          _viajesPlanificados = List<Map<String, dynamic>>.from(pendingViajes);
          _cargasTerminadas = history;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredHistory = _cargasTerminadas.where((c) {
        final codeMatch = (c['carga_codigo'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          (c['viaje']?['viaje_codigo'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
        
        bool dateMatch = true;
        if (_selectedDate != null) {
          final updated = DateTime.tryParse(c['updated_at'] ?? '');
          dateMatch = updated != null && 
                      updated.year == _selectedDate!.year && 
                      updated.month == _selectedDate!.month && 
                      updated.day == _selectedDate!.day;
        }
        return codeMatch && dateMatch;
      }).toList();
    });
  }

  Future<void> _confirmarCarga(Map<String, dynamic> viaje, double totalKg, int totalTambores) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Salida', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Confirma que el viaje ${viaje['viaje_codigo']} ha sido cargado físicamente y está listo para salir?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CONFIRMAR')),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await SupabaseService().confirmarCargaViaje(viaje['id']);
        await _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carga del viaje confirmada exitosamente'), backgroundColor: Colors.green));
          _tabController.animateTo(1);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GeoLogística Depósito', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 18)),
            Text('Gestión de Cargas y Salidas', style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant).copyWith(fontSize: 12)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: DesignTokens.primary,
          unselectedLabelColor: DesignTokens.onSurfaceVariant,
          indicatorColor: DesignTokens.secondary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'PENDIENTES'),
            Tab(text: 'TERMINADAS'),
          ],
        ),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildPendientesTab(),
              _buildTerminadasTab(),
            ],
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCargaDialog,
        backgroundColor: DesignTokens.primary,
        icon: Icon(Icons.add_box_rounded, color: DesignTokens.accent),
        label: const Text('AGREGAR CARGA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPendientesTab() {
    if (_viajesPlanificados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 64, color: DesignTokens.primary.withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text('No hay viajes pendientes de carga.'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _viajesPlanificados.length,
      itemBuilder: (context, index) {
        final v = _viajesPlanificados[index];
        final chofer = v['profiles'] ?? {};
        final vehiculo = v['vehiculos'] ?? {};
        
        double totalKg = 0;
        int totalTambores = 0;
        for (var p in (v['paradas'] as List? ?? [])) {
          for (var item in (p['parada_items'] as List? ?? [])) {
            final double cant = (item['cantidad'] ?? 0).toDouble();
            final String prod = (item['producto_codigo'] ?? '').toString().toLowerCase();
            if (prod.contains('tcm')) { totalKg += cant * 300; totalTambores += cant.toInt(); }
            else if (prod.contains('vacio') || prod.contains('vacío') || prod.contains('tv')) { totalKg += cant * 20; totalTambores += cant.toInt(); }
            else { totalKg += cant; }
          }
        }

        final capKg = (vehiculo['capacidad_kg'] ?? 0).toDouble();
        final excede = capKg > 0 && totalKg > capKg;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DesignTokens.primary.withOpacity(0.06)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v['viaje_codigo'] ?? 'S/C', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: DesignTokens.primary)),
                        Text('Chofer: ${chofer['nombre'] ?? 'S/N'} ${chofer['apellido'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    Icon(Icons.inventory_2_outlined, color: DesignTokens.secondary),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricCol('PESO TOTAL', '${totalKg.round()} Kg', Icons.scale),
                    _metricCol('TAMBORES', '$totalTambores un.', Icons.inventory_2),
                    _metricCol('UNIDAD', v['vehiculo_codigo'] ?? 'S/D', Icons.local_shipping),
                  ],
                ),
                if (excede) ...[
                  const SizedBox(height: 8),
                  const Text('⚠️ Excede capacidad del vehículo', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmarCarga(v, totalKg, totalTambores),
                    style: DesignTokens.primaryButtonStyle,
                    icon: const Icon(Icons.check_circle_outline, color: DesignTokens.accent),
                    label: const Text('CONFIRMAR CARGA Y SALIDA'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTerminadasTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por código...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) {
                    _searchQuery = val;
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                    _applyFilters();
                  }
                },
                icon: Icon(Icons.calendar_month, color: _selectedDate != null ? DesignTokens.accent : Colors.white),
                style: IconButton.styleFrom(backgroundColor: DesignTokens.primary),
              ),
              if (_selectedDate != null)
                IconButton(onPressed: () { setState(() => _selectedDate = null); _applyFilters(); }, icon: const Icon(Icons.clear, color: Colors.red)),
            ],
          ),
        ),
        Expanded(
          child: _filteredHistory.isEmpty
            ? const Center(child: Text('No se encontraron cargas terminadas.'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filteredHistory.length,
                itemBuilder: (ctx, i) => _buildHistoryCard(_filteredHistory[i]),
              ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> c) {
    final updated = DateTime.tryParse(c['updated_at'] ?? '');
    final dateStr = updated != null ? DateFormat('dd/MM/yyyy HH:mm').format(updated) : 'S/F';
    final items = List<Map<String, dynamic>>.from(c['carga_items'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, color: Colors.green),
        ),
        title: Text(c['carga_codigo'] ?? 'CARGA', style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Viaje: ${c['viaje']?['viaje_codigo'] ?? 'S/V'}', style: const TextStyle(fontSize: 12)),
            Text('Fecha: $dateStr', style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => context.push('/remito_carga?cargaId=${c['id']}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: DesignTokens.secondary,
            foregroundColor: DesignTokens.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text('REMITO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ),
    );
  }

  Widget _metricCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: DesignTokens.primary.withOpacity(0.4)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: DesignTokens.primary.withOpacity(0.4))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: DesignTokens.primary)),
      ],
    );
  }

  void _showAddCargaDialog() {
    Map<String, dynamic>? selectedViaje;
    Map<String, dynamic>? selectedProducto;
    final qtyController = TextEditingController();
    List<Map<String, dynamic>> products = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (products.isEmpty) {
            Supabase.instance.client.from('productos').select().then((data) {
              if (ctx.mounted) setModalState(() => products = data);
            });
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Asignar Carga a Viaje', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 20)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedViaje,
                    decoration: const InputDecoration(labelText: 'Seleccionar Viaje', prefixIcon: Icon(Icons.local_shipping_rounded)),
                    items: _viajesPlanificados.map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v['viaje_codigo'] ?? 'S/C'),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedViaje = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedProducto,
                    decoration: const InputDecoration(labelText: 'Producto', prefixIcon: Icon(Icons.inventory_2_rounded)),
                    items: products.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p['descripcion'] ?? 'S/N'),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedProducto = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad', prefixIcon: Icon(Icons.numbers_rounded)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedViaje == null || selectedProducto == null || qtyController.text.isEmpty) return;
                        try {
                          // Simplified: creating a carga for the trip
                          final humanId = 'CAR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                          final cargaResp = await Supabase.instance.client.from('cargas').insert({
                            'viaje_id': selectedViaje!['id'],
                            'carga_codigo': humanId,
                            'estado': AppStates.pendiente,
                          }).select('id').single();
                          
                          await Supabase.instance.client.from('carga_items').insert({
                            'carga_id': cargaResp['id'],
                            'producto_codigo': selectedProducto!['descripcion'],
                            'cantidad': double.tryParse(qtyController.text) ?? 0,
                            'unidad': selectedProducto!['unidad'] ?? 'UN',
                          });

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _fetchData();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carga asignada correctamente')));
                          }
                        } catch (e) {
                          if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      style: DesignTokens.primaryButtonStyle,
                      child: const Text('ASIGNAR CARGA'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
