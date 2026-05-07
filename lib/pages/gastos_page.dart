import '../flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import 'package:intl/intl.dart';

class GastosPageWidget extends StatefulWidget {
  const GastosPageWidget({super.key});

  @override
  State<GastosPageWidget> createState() => _GastosPageWidgetState();
}

class _GastosPageWidgetState extends State<GastosPageWidget> {
  List<Map<String, dynamic>> _gastos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final data = await SupabaseService().getGastos();
    if (mounted) {
      setState(() {
        _gastos = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DesignTokens.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Gestión de Gastos',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: DesignTokens.primary),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _gastos.length,
              itemBuilder: (context, index) {
                final g = _gastos[index];
                return _buildGastoCard(g);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGastoDialog(),
        backgroundColor: DesignTokens.secondary,
        icon: const Icon(Icons.add_a_photo_rounded, color: DesignTokens.primary),
        label: const Text('NUEVO GASTO', style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildGastoCard(Map<String, dynamic> g) {
    final tipo = g['tipo_gasto'] ?? 'Gasto';
    final importe = g['importe']?.toString() ?? '0';
    final fecha = DateTime.tryParse(g['fecha']?.toString() ?? '') ?? DateTime.now();
    final fechaStr = DateFormat('dd/MM/yyyy').format(fecha);
    final chofer = g['profiles'] != null ? '${g['profiles']['nombre']} ${g['profiles']['apellido']}' : 'S/D';
    final viaje = g['viajes']?['viaje_codigo'] ?? 'Sin viaje';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: DesignTokens.primary.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(tipo.toUpperCase(), style: const TextStyle(color: Color(0xFF7D5700), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Text('\$ $importe', style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: DesignTokens.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 14, color: DesignTokens.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(chofer, style: const TextStyle(fontSize: 12, color: DesignTokens.onSurfaceVariant)),
              const Spacer(),
              const Icon(Icons.calendar_today_rounded, size: 14, color: DesignTokens.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(fechaStr, style: const TextStyle(fontSize: 12, color: DesignTokens.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, size: 14, color: DesignTokens.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('Viaje: $viaje', style: const TextStyle(fontSize: 12, color: DesignTokens.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddGastoDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    final comprobanteController = TextEditingController();
    String? selectedTipo = 'Combustible';
    String? selectedMetodo = 'Efectivo';
    DateTime selectedFecha = DateTime.now();
    Map<String, dynamic>? selectedViaje;

    // Local list of trips for the dropdown
    List<Map<String, dynamic>> availableTrips = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Initialize trips if empty
          if (availableTrips.isEmpty) {
            Supabase.instance.client.from('viajes').select('id, viaje_codigo').order('created_at', ascending: false).limit(20).then((data) {
              if (ctx.mounted) setModalState(() => availableTrips = data);
            });
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Registrar Nuevo Gasto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
                  const SizedBox(height: 20),
                  
                  // Fila de Fecha y Comprobante
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedFecha,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setModalState(() => selectedFecha = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Fecha', prefixIcon: Icon(Icons.calendar_today_rounded)),
                            child: Text(DateFormat('dd/MM/yyyy').format(selectedFecha)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: comprobanteController,
                          decoration: const InputDecoration(labelText: 'N° Comprobante', prefixIcon: Icon(Icons.receipt_rounded)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: selectedTipo,
                    decoration: const InputDecoration(labelText: 'Tipo de Gasto', prefixIcon: Icon(Icons.category_rounded)),
                    items: ['Combustible', 'Comida', 'Peaje', 'Reparación', 'Otros']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedTipo = v),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedViaje,
                    decoration: const InputDecoration(labelText: 'Vincular a Viaje', prefixIcon: Icon(Icons.local_shipping_rounded)),
                    hint: const Text('Seleccione un viaje...'),
                    items: availableTrips.map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v['viaje_codigo'] ?? 'S/C'),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedViaje = v),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Importe (\$)', prefixIcon: Icon(Icons.attach_money_rounded)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedMetodo,
                          decoration: const InputDecoration(labelText: 'Forma de Pago'),
                          items: ['Efectivo', 'Tarjeta', 'Transferencia', 'Cuenta Corriente']
                              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (v) => setModalState(() => selectedMetodo = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Observaciones', prefixIcon: Icon(Icons.notes_rounded)),
                  ),
                  const SizedBox(height: 20),

                   // Sección de Foto (Ahora interactiva)
                   InkWell(
                     onTap: () async {
                       ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                         content: Text('Cámara solicitada. Por favor, adjunte el comprobante.'),
                         duration: Duration(seconds: 2),
                       ));
                     },
                     child: Container(
                       width: double.infinity,
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: DesignTokens.surface,
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                       ),
                       child: Column(
                         children: [
                           const Icon(Icons.camera_alt_rounded, size: 32, color: DesignTokens.primary),
                           const SizedBox(height: 8),
                           const Text('ADJUNTAR FOTO DEL TICKET', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
                           const SizedBox(height: 4),
                           Text('Obligatorio para rendición', style: TextStyle(fontSize: 10, color: DesignTokens.onSurfaceVariant.withOpacity(0.6))),
                         ],
                       ),
                     ),
                   ),

                  const SizedBox(height: 28),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (amountController.text.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Ingrese el importe')));
                          return;
                        }
                        try {
                          final user = Supabase.instance.client.auth.currentUser;
                          await Supabase.instance.client.from('gastos').insert({
                            'tipo_gasto': selectedTipo,
                            'importe': double.tryParse(amountController.text) ?? 0,
                            'descripcion': descController.text,
                            'nro_comprobante': comprobanteController.text,
                            'forma_pago': selectedMetodo,
                            'viaje_id': selectedViaje?['id'],
                            'fecha': selectedFecha.toIso8601String(),
                            'chofer_id': user?.id,
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _fetchData();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gasto registrado con éxito'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        }
                      },
                      style: DesignTokens.primaryButtonStyle,
                      child: const Text('GUARDAR REGISTRO'),
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
