import '../flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

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
        onPressed: _showAddGastoDialog,
        backgroundColor: DesignTokens.primary,
        icon: const Icon(Icons.payments_rounded, color: Colors.white),
        label: const Text('NUEVO GASTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    XFile? pickedFile;

    // Local list of trips for the dropdown
    List<Map<String, dynamic>> availableTrips = [];
    bool _savingGasto = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Initialize trips if empty
          if (availableTrips.isEmpty) {
            Supabase.instance.client
                .from('viajes')
                .select('id, viaje_codigo, estado')
                .inFilter('estado', ['En Curso', 'En Proceso', 'Cargado', 'Iniciado'])
                .order('fecha', ascending: false)
                .limit(20)
                .then((data) {
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
                            decoration: InputDecoration(
                              labelText: 'Fecha',
                              prefixIcon: const Icon(Icons.calendar_today_rounded, color: DesignTokens.primary),
                              filled: true,
                              fillColor: DesignTokens.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                            ),
                            child: Text(DateFormat('dd/MM/yyyy').format(selectedFecha), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: comprobanteController,
                          decoration: InputDecoration(
                            labelText: 'N° Comprobante',
                            prefixIcon: const Icon(Icons.receipt_rounded, color: DesignTokens.primary),
                            filled: true,
                            fillColor: DesignTokens.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.secondary.withOpacity(0.1), width: 2)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: selectedTipo,
                    decoration: InputDecoration(
                      labelText: 'Tipo de Gasto',
                      prefixIcon: const Icon(Icons.category_rounded, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.secondary.withOpacity(0.1), width: 2)),
                    ),
                    items: ['Combustible', 'Comida', 'Peaje', 'Reparación', 'Otros']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedTipo = v),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedViaje,
                    decoration: InputDecoration(
                      labelText: 'Vincular a Viaje',
                      prefixIcon: const Icon(Icons.local_shipping_rounded, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.secondary.withOpacity(0.1), width: 2)),
                    ),
                    hint: const Text('Seleccione un viaje...'),
                    items: availableTrips.map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v['viaje_codigo'] ?? 'S/C'),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedViaje = v),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Importe (\$)',
                      prefixIcon: const Icon(Icons.attach_money_rounded, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.secondary.withOpacity(0.1), width: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedMetodo,
                    decoration: InputDecoration(
                      labelText: 'Forma de Pago',
                      prefixIcon: const Icon(Icons.payment_rounded, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.secondary.withOpacity(0.1), width: 2)),
                    ),
                    items: ['Efectivo', 'Tarjeta', 'Transferencia', 'Cuenta Corriente']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedMetodo = v),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Observaciones',
                      alignLabelWithHint: true,
                      prefixIcon: const Icon(Icons.notes_rounded, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.secondary.withOpacity(0.1), width: 2)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 20),

                   // Sección de Foto (Ahora funcional)
                   InkWell(
                     onTap: () async {
                       final ImagePicker picker = ImagePicker();
                       final XFile? image = await picker.pickImage(source: ImageSource.camera);
                       if (image != null) {
                         setModalState(() => pickedFile = image);
                       }
                     },
                     child: Container(
                       width: double.infinity,
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: DesignTokens.surface,
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                       ),
                       child: pickedFile != null 
                         ? Column(
                             children: [
                               ClipRRect(
                                 borderRadius: BorderRadius.circular(8),
                                 child: Image.file(File(pickedFile!.path), height: 100, width: double.infinity, fit: BoxFit.cover),
                               ),
                               const SizedBox(height: 8),
                               const Text('FOTO ADJUNTADA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                               const Text('Toca para cambiar', style: TextStyle(fontSize: 10, color: Colors.black26)),
                             ],
                           )
                         : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo_rounded, size: 32, color: DesignTokens.primary),
                              const SizedBox(height: 8),
                              Text(pickedFile == null ? 'ADJUNTAR FOTO' : 'CAMBIAR FOTO', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
                             ],
                           ),
                     ),
                   ),

                  const SizedBox(height: 28),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _savingGasto ? null : () async {
                        if (amountController.text.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Ingrese el importe')));
                          return;
                        }
                        setModalState(() => _savingGasto = true);
                        try {
                          String? publicUrl;
                          if (pickedFile != null) {
                            final bytes = await pickedFile!.readAsBytes();
                            final ext = p.extension(pickedFile!.path);
                            final fileName = 'gasto_${DateTime.now().millisecondsSinceEpoch}$ext';
                            
                            await Supabase.instance.client.storage.from('gastos').uploadBinary(
                              fileName, 
                              bytes,
                              fileOptions: const FileOptions(contentType: 'image/jpeg'),
                            );
                            publicUrl = Supabase.instance.client.storage.from('gastos').getPublicUrl(fileName);
                          }

                          final prefs = await SharedPreferences.getInstance();
                          final userId = prefs.getString('user_id');
                          await Supabase.instance.client.from('gastos').insert({
                            'tipo_gasto': selectedTipo,
                            'importe': double.tryParse(amountController.text) ?? 0,
                            'descripcion': descController.text,
                            'nro_comprobante': comprobanteController.text,
                            'forma_pago': selectedMetodo,
                            'viaje_id': selectedViaje?['id'],
                            'fecha': selectedFecha.toIso8601String(),
                            'chofer_id': userId,
                            'comprobante_url': publicUrl,
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _fetchData();
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Gasto registrado con éxito'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          print('Error saving gasto: $e');
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                          }
                        } finally {
                          if (ctx.mounted) setModalState(() => _savingGasto = false);
                        }
                      },
                      style: DesignTokens.primaryButtonStyle,
                      child: _savingGasto 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('GUARDAR REGISTRO'),
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
