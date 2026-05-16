import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signature/signature.dart';
import 'package:go_router/go_router.dart';
import '../backend/design_tokens.dart';
import '../backend/supabase_service.dart';

class RemitoRegistroPage extends StatefulWidget {
  final String paradaId;
  final String? apicultorId;
  final String? apicultorNombre;
  final String? apicultorDni;
  final String tipoOperacion; // 'recoleccion' or 'distribucion'

  const RemitoRegistroPage({
    super.key,
    required this.paradaId,
    this.apicultorId,
    this.apicultorNombre,
    this.apicultorDni,
    required this.tipoOperacion,
  });

  @override
  State<RemitoRegistroPage> createState() => _RemitoRegistroPageState();
}

class _RemitoRegistroPageState extends State<RemitoRegistroPage> {
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isApicultorFirmante = true;
  final _firmanteNombreController = TextEditingController();
  final _firmanteDniController = TextEditingController();
  
  List<Map<String, dynamic>> _availableItems = [];
  Map<String, double> _selectedQuantities = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
    if (widget.apicultorNombre != null) {
      _firmanteNombreController.text = widget.apicultorNombre!;
      _firmanteDniController.text = widget.apicultorDni ?? '';
    }
  }

  List<Map<String, dynamic>> _pesajes = [];

  Future<void> _loadItems() async {
    try {
      final itemsFuture = Supabase.instance.client
          .from('parada_items')
          .select('*')
          .eq('parada_id', widget.paradaId);
          
      final pesajesFuture = Supabase.instance.client
          .from('pesajes')
          .select('*')
          .eq('parada_id', widget.paradaId);

      final results = await Future.wait([itemsFuture, pesajesFuture]);
      
      setState(() {
        _availableItems = List<Map<String, dynamic>>.from(results[0]);
        _pesajes = List<Map<String, dynamic>>.from(results[1]);
        
        for (var item in _availableItems) {
          final id = item['id'].toString();
          // Si es TCM y hay pesajes, sugerimos la cantidad de pesajes
          if (item['producto_codigo'] == 'TCM' && _pesajes.isNotEmpty) {
            _selectedQuantities[id] = _pesajes.length.toDouble();
          } else {
            _selectedQuantities[id] = (item['cantidad'] as num).toDouble();
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading items/pesajes: $e');
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _firmanteNombreController.dispose();
    _firmanteDniController.dispose();
    super.dispose();
  }

  Future<void> _guardarRemito() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, capture la firma')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      final signatureBase64 = base64Encode(signatureBytes!);

      // 1. Create Remito Record
      final remitoData = {
        'parada_id': widget.paradaId,
        'entidad_nombre': widget.apicultorNombre,
        'firmante_nombre': _firmanteNombreController.text,
        'firmante_dni': _firmanteDniController.text,
        'firma_base64': signatureBase64,
        'tipo': widget.tipoOperacion,
        'fecha': DateTime.now().toIso8601String(),
        'items': _availableItems.map((it) {
          final selQty = _selectedQuantities[it['id'].toString()] ?? 0;
          return {
            'producto_codigo': it['producto_codigo'],
            'cantidad': selQty,
            'unidad': it['unidad'],
          };
        }).where((it) => (it['cantidad'] as num) > 0).toList(),
      };

      // Assuming a 'remitos' table exists with these columns (we'll adapt if needed)
      // For now, we'll store it and the user can later sync it to PDF
      await Supabase.instance.client.from('remitos').insert(remitoData);

      if (mounted) {
        context.pop(true); // Return success
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar remito: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRecoleccion = widget.tipoOperacion.toLowerCase().contains('recolec');
    final titleLabel = isRecoleccion ? 'APICULTOR ENTREGA' : 'APICULTOR RECIBE';

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Nuevo Remito', style: DesignTokens.headlineStyle().copyWith(fontSize: 18)),
        backgroundColor: DesignTokens.surface,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleLabel, style: DesignTokens.labelStyle()),
                const SizedBox(height: 8),
                Text(widget.apicultorNombre ?? 'Sin Apicultor', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 24),
                
                const Text('¿QUIÉN FIRMA?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DesignTokens.onSurfaceVariant)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('El Apicultor', style: TextStyle(fontSize: 14)),
                        value: true,
                        groupValue: _isApicultorFirmante,
                        onChanged: (val) => setState(() {
                          _isApicultorFirmante = val!;
                          if (val) {
                            _firmanteNombreController.text = widget.apicultorNombre ?? '';
                            _firmanteDniController.text = widget.apicultorDni ?? '';
                          }
                        }),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Un Tercero', style: TextStyle(fontSize: 14)),
                        value: false,
                        groupValue: _isApicultorFirmante,
                        onChanged: (val) => setState(() {
                          _isApicultorFirmante = val!;
                          if (!val) {
                            _firmanteNombreController.clear();
                            _firmanteDniController.clear();
                          }
                        }),
                      ),
                    ),
                  ],
                ),
                
                if (!_isApicultorFirmante) ...[
                  TextField(
                    controller: _firmanteNombreController,
                    decoration: const InputDecoration(labelText: 'Nombre del Tercero'),
                  ),
                  TextField(
                    controller: _firmanteDniController,
                    decoration: const InputDecoration(labelText: 'DNI / CUIT'),
                    keyboardType: TextInputType.number,
                  ),
                ],
                
                const SizedBox(height: 32),
                const Text('ITEMS A INCLUIR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DesignTokens.onSurfaceVariant)),
                const SizedBox(height: 12),
                ..._availableItems.map((item) {
                  final id = item['id'].toString();
                  final isTCM = item['producto_codigo'] == 'TCM';
                  final qty = _selectedQuantities[id] ?? 0;
                  final hasMismatch = isTCM && _pesajes.isNotEmpty && qty != _pesajes.length;

                  return Column(
                    children: [
                      Card(
                        child: ListTile(
                          title: Text(item['producto_codigo'] ?? ''),
                          subtitle: Text('Máximo planificado: ${item['cantidad']} ${item['unidad']}'),
                          trailing: SizedBox(
                            width: 80,
                            child: TextField(
                              decoration: const InputDecoration(isDense: true),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                setState(() {
                                  _selectedQuantities[id] = double.tryParse(val) ?? 0;
                                });
                              },
                              controller: TextEditingController.fromValue(
                                TextEditingValue(
                                  text: qty.toString(),
                                  selection: TextSelection.collapsed(offset: qty.toString().length),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (hasMismatch)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Aviso: Seleccionaste $qty TCM pero solo hay ${_pesajes.length} pesajes registrados.',
                                  style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  );
                }),
                
                const SizedBox(height: 32),
                const Text('FIRMA DIGITAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DesignTokens.onSurfaceVariant)),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    color: Colors.white,
                  ),
                  child: Signature(
                    controller: _signatureController,
                    backgroundColor: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () => _signatureController.clear(),
                  child: const Text('LIMPIAR FIRMA'),
                ),
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _guardarRemito,
                    style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary),
                    child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('GENERAR Y FIRMAR REMITO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
