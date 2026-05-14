import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/design_tokens.dart';
import '../backend/supabase_service.dart';

class DepositoHomeWidget extends StatefulWidget {
  const DepositoHomeWidget({super.key});

  @override
  State<DepositoHomeWidget> createState() => _DepositoHomeWidgetState();
}

class _DepositoHomeWidgetState extends State<DepositoHomeWidget> {
  List<Map<String, dynamic>> _viajesPlanificados = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('viajes')
          .select('*, profiles(nombre, apellido), paradas(*, parada_items(*)), vehiculos:vehiculo_codigo(capacidad_kg, capacidad_tambores)')
          .or('estado.eq.Planificado,estado.eq.Pendiente')
          .order('fecha', ascending: true);

      if (mounted) {
        setState(() {
          _viajesPlanificados = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmarCarga(Map<String, dynamic> viaje, double totalKg, int totalTambores) async {
    final vehiculo = viaje['vehiculos'] ?? {};
    final capKg = (vehiculo['capacidad_kg'] ?? 0).toDouble();
    final capTambores = (vehiculo['capacidad_tambores'] ?? 0);

    final excede = (capKg > 0 && totalKg > capKg) || (capTambores > 0 && totalTambores > capTambores);

    if (excede) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ ALERTA DE SOBRECARGA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text('La carga actual (${totalKg.toStringAsFixed(0)}kg / $totalTambores tamb.) EXCEDE la capacidad del vehículo (${capKg.toStringAsFixed(0)}kg / $capTambores tamb.).\n\n¿Desea confirmar la salida de todas formas?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CONFIRMAR SOBRECARGA', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (continuar != true) return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Carga'),
        content: Text('¿Confirma que el vehículo ${viaje['vehiculo_codigo']} ha sido cargado según lo planificado para el viaje ${viaje['viaje_codigo']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CONFIRMAR')),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await SupabaseService().updateViajeEstado(viaje['id'], 'Cargado');
        _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viaje marcado como CARGADO'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        title: Text('Módulo de Depósito', style: DesignTokens.headlineStyle()),
        iconTheme: IconThemeData(color: DesignTokens.primary),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Viajes para Cargar', style: DesignTokens.headlineStyle(color: DesignTokens.primary)),
                    Text('Confirme la salida física de mercadería de planta.', style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant)),
                  ],
                ),
              ),
              Expanded(
                child: _viajesPlanificados.isEmpty 
                  ? const Center(child: Text('No hay viajes planificados pendientes de carga.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                            
                            if (prod.contains('tcm')) {
                              totalKg += cant * 300;
                              totalTambores += cant.toInt();
                            } else if (prod.contains('vacio') || prod.contains('vacío') || prod.contains('tv')) {
                              totalKg += cant * 20;
                              totalTambores += cant.toInt();
                            } else {
                              totalKg += cant;
                            }
                          }
                        }

                        final capKg = (vehiculo['capacidad_kg'] ?? 0).toDouble();
                        final excede = capKg > 0 && totalKg > capKg;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: excede ? DesignTokens.error.withOpacity(0.3) : DesignTokens.outline.withOpacity(0.2)),
                            boxShadow: [BoxShadow(color: excede ? DesignTokens.error.withOpacity(0.05) : Colors.black.withOpacity(0.02), blurRadius: 10)],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(v['viaje_codigo'] ?? 'S/C', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 16)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: DesignTokens.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                      child: Text(v['vehiculo_codigo'] ?? 'N/A', style: DesignTokens.labelStyle(color: DesignTokens.primary)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.person_pin_circle_rounded, size: 16, color: Colors.black45),
                                    const SizedBox(width: 8),
                                    Text('Chofer: ${chofer['nombre']} ${chofer['apellido']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                  ],
                                ),
                                const Divider(height: 24),
                                // Resumen de Carga
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('CARGA TOTAL', style: DesignTokens.labelStyle().copyWith(fontSize: 9)),
                                        Text('${totalKg.toStringAsFixed(0)} KG', style: DesignTokens.headlineStyle(color: excede ? DesignTokens.error : DesignTokens.primary).copyWith(fontSize: 16)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('TAMBORES', style: DesignTokens.labelStyle().copyWith(fontSize: 9)),
                                        Text('$totalTambores un.', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 16)),
                                      ],
                                    ),
                                  ],
                                ),
                                if (excede) ...[
                                  const SizedBox(height: 8),
                                  Text('⚠️ Excede capacidad (${capKg.toStringAsFixed(0)} Kg)', style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                                const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _confirmarCarga(v, totalKg, totalTambores),
                                      style: DesignTokens.primaryButtonStyle,
                                      icon: Icon(Icons.check_circle_outline, color: DesignTokens.accent),
                                      label: const Text('CONFIRMAR CARGA Y SALIDA'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
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
                          // Create a 'Distribución' stop/item for the trip
                          // This logic depends on your schema, but usually we add a parada or link item
                          // For now, let's assume we insert into 'paradas' or similar
                          final res = await Supabase.instance.client.from('paradas').insert({
                            'viaje_id': selectedViaje!['id'],
                            'tipo': 'Distribución',
                            'estado': 'Planificada',
                            'orden': 1,
                            'localidad': 'General Pico', // Default to plant for distributions from plant
                            'nombre_sitio': 'Depósito Central',
                          }).select().single();

                          await Supabase.instance.client.from('parada_items').insert({
                            'parada_id': res['id'],
                            'producto': selectedProducto!['descripcion'],
                            'cantidad_planificada': double.tryParse(qtyController.text) ?? 0,
                            'unidad': selectedProducto!['unidad'] ?? 'u',
                          });

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _fetchData();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carga asignada correctamente'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF08201A), foregroundColor: Colors.white),
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
