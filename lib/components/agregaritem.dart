import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgregarItemWidget extends StatefulWidget {
  const AgregarItemWidget({super.key, required this.paradaId});
  final String? paradaId;

  @override
  State<AgregarItemWidget> createState() => _AgregarItemWidgetState();
}

class _AgregarItemWidgetState extends State<AgregarItemWidget> {
  final _textController = TextEditingController();
  String? _selectedProduct;
  List<Map<String, dynamic>> _productos = [];

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }

  Future<void> _loadProductos() async {
    final response = await Supabase.instance.client.from('productos').select();
    setState(() {
      _productos = List<Map<String, dynamic>>.from(response);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Agregar Item',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedProduct,
            hint: const Text('Seleccionar Producto'),
            items: _productos.map((prod) => DropdownMenuItem(
              value: prod['codigo']?.toString(),
              child: Text(prod['descripcion']?.toString() ?? '--'),
            )).toList(),
            onChanged: (val) => setState(() => _selectedProduct = val),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              if (widget.paradaId != null && _selectedProduct != null) {
                await Supabase.instance.client.from('parada_items').insert({
                  'parada_id': widget.paradaId,
                  'producto_codigo': _selectedProduct,
                  'cantidad': double.tryParse(_textController.text),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('Guardar', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
