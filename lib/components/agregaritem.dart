import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/design_tokens.dart';
import '../backend/supabase_service.dart';

class AgregarItemWidget extends StatefulWidget {
  const AgregarItemWidget({super.key, required this.paradaId});
  final String? paradaId;

  @override
  State<AgregarItemWidget> createState() => _AgregarItemWidgetState();
}

class _AgregarItemWidgetState extends State<AgregarItemWidget> {
  final _textController = TextEditingController();
  String? _selectedProduct;
  String? _selectedUnit;
  String _tipoMovimiento = 'Recolección'; // 'Recolección' (Retira) o 'Distribución' (Entrega)
  List<Map<String, dynamic>> _productos = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }

  Future<void> _loadProductos() async {
    try {
      final response = await SupabaseService().getProductos();
      setState(() {
        _productos = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error cargando productos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text(
            'Agregar Producto / Insumo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: DesignTokens.primary, fontFamily: 'Manrope'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Seleccioná el tipo de operación y el producto.',
            style: TextStyle(fontSize: 13, color: DesignTokens.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Selector de Tipo de Movimiento
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: DesignTokens.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tipoMovimiento = 'Recolección'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _tipoMovimiento == 'Recolección' ? DesignTokens.secondary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'RECOLECCIÓN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _tipoMovimiento == 'Recolección' ? Colors.white : DesignTokens.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tipoMovimiento = 'Distribución'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _tipoMovimiento == 'Distribución' ? DesignTokens.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'DISTRIBUCIÓN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _tipoMovimiento == 'Distribución' ? Colors.white : DesignTokens.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedProduct,
            hint: const Text('Buscar Producto...'),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: DesignTokens.primary),
            decoration: InputDecoration(
              filled: true,
              fillColor: DesignTokens.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            items: _productos.map((prod) => DropdownMenuItem(
              value: prod['codigo']?.toString(),
              child: Text(prod['descripcion']?.toString() ?? '--', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            )).toList(),
            onChanged: (val) {
              setState(() {
                _selectedProduct = val;
                final p = _productos.firstWhere((element) => element['codigo'].toString() == val);
                _selectedUnit = p['unidad']?.toString() ?? 'Unidades';
              });
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _textController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            decoration: InputDecoration(
              labelText: _selectedUnit != null ? 'Cantidad ($_selectedUnit)' : 'Cantidad',
              filled: true,
              fillColor: DesignTokens.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.calculate_outlined, color: DesignTokens.primary),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: (_isSaving || _selectedProduct == null) ? null : () async {
                setState(() => _isSaving = true);
                try {
                  if (widget.paradaId != null && _selectedProduct != null) {
                    // 1. Insert Item
                    final bool isTCM = _selectedProduct == 'TCM';
                    await Supabase.instance.client.from('parada_items').insert({
                      'parada_id': widget.paradaId,
                      'producto_codigo': _selectedProduct,
                      'cantidad': double.tryParse(_textController.text) ?? 0,
                      'unidad': isTCM ? 'uni' : (_selectedUnit ?? 'Uni'),
                    });

                    // 2. Si es Recolección, asegurar que la parada sea Mixta o Recolección
                    if (_tipoMovimiento == 'Recolección') {
                      final parada = await Supabase.instance.client.from('paradas')
                          .select('tipo')
                          .eq('id', widget.paradaId!)
                          .single();
                      
                      String currentTipo = (parada['tipo'] ?? '').toString();
                      if (!currentTipo.toLowerCase().contains('recolec') && !currentTipo.toLowerCase().contains('mixta')) {
                        String newTipo = currentTipo.isEmpty ? 'Recolección' : 'MIXTA';
                        await Supabase.instance.client.from('paradas')
                            .update({'tipo': newTipo})
                            .eq('id', widget.paradaId!);
                      }
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                } finally {
                  if (mounted) setState(() => _isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSaving 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : const Text('GUARDAR ITEM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
