import '../flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import '../backend/supabase_service.dart';
import 'package:go_router/go_router.dart';

class ProductosPageWidget extends StatefulWidget {
  const ProductosPageWidget({super.key});

  @override
  State<ProductosPageWidget> createState() => _ProductosPageWidgetState();
}

class _ProductosPageWidgetState extends State<ProductosPageWidget> {
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  // Stitch colors
  static const kPrimary = Color(0xFF08201A);
  static const kSecContainer = Color(0xFFFDBE49);
  static const kSurface = Color(0xFFFBF9F8);
  static const kOnSurfaceVariant = Color(0xFF424846);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final data = await SupabaseService().getProductos();
    if (mounted) {
      setState(() {
        _productos = data;
        _filtered = data;
        _loading = false;
      });
    }
  }

  void _onSearch(String val) {
    setState(() {
      _filtered = _productos.where((p) {
        final name = (p['nombre'] ?? '').toString().toLowerCase();
        final code = (p['categoria'] ?? '').toString().toLowerCase(); // Usamos categoria como sigla si no hay columna
        return name.contains(val.toLowerCase()) || code.contains(val.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Catálogo de Productos',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: kPrimary),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o siglas...',
                prefixIcon: const Icon(Icons.search, color: kPrimary),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kSecContainer))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final p = _filtered[index];
                      return _buildProductCard(p);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: kPrimary,
        child: const Icon(Icons.add, color: kSecContainer),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final nombre = p['nombre'] ?? 'Sin nombre';
    final sigla = p['categoria'] ?? 'S/D';
    final stock = p['stock_actual']?.toString() ?? '0';
    final unidad = p['unidad'] ?? 'un.';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: kPrimary.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.inventory_2_rounded, color: kPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, fontSize: 16, color: kPrimary)),
                Text('Sigla: $sigla', style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$stock $unidad', style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 16, color: kPrimary)),
              const Text('STOCK', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: kOnSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}
