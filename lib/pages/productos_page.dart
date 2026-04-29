import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/supabase_service.dart';

class ProductosPageWidget extends StatefulWidget {
  const ProductosPageWidget({super.key});

  @override
  State<ProductosPageWidget> createState() => _ProductosPageWidgetState();
}

class _ProductosPageWidgetState extends State<ProductosPageWidget> {
  List<Map<String, dynamic>> _productos = [];
  bool _loading = true;

  static const kPrimary = Color(0xFF08201A);
  static const kSecContainer = Color(0xFFFDBE49);
  static const kSurface = Color(0xFFFBF9F8);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await Supabase.instance.client.from('productos').select().order('descripcion');
      if (mounted) {
        setState(() {
          _productos = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        title: const Text('Inventario de Productos', style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kPrimary), onPressed: () => context.pop()),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: kSecContainer))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _productos.length,
            itemBuilder: (context, index) => _buildProductCard(_productos[index]),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        backgroundColor: kPrimary,
        child: const Icon(Icons.add, color: kSecContainer),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kPrimary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.inventory_2_rounded, color: kPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['descripcion'] ?? 'Sin descripción', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Código: ${p['codigo'] ?? 'S/C'}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: kSecContainer.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Text(p['unidad'] ?? 'UN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: kPrimary)),
          ),
        ],
      ),
    );
  }

  void _addProduct() {
    final descController = TextEditingController();
    final codeController = TextEditingController();
    String? selectedUnidad = 'KG';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nuevo Producto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimary)),
              const SizedBox(height: 20),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Descripción', prefixIcon: Icon(Icons.inventory_2_outlined)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Código de Producto', prefixIcon: Icon(Icons.qr_code_rounded)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedUnidad,
                decoration: const InputDecoration(labelText: 'Unidad de Medida'),
                items: ['KG', 'UN', 'L', 'Tambor']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setModalState(() => selectedUnidad = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (descController.text.isEmpty) return;
                    try {
                      await Supabase.instance.client.from('productos').insert({
                        'descripcion': descController.text,
                        'codigo': codeController.text,
                        'unidad': selectedUnidad,
                      });
                      Navigator.pop(ctx);
                      _fetchData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                  child: const Text('GUARDAR PRODUCTO'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
