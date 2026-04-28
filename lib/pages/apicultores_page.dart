import '../flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import '../backend/supabase_service.dart';
import 'package:go_router/go_router.dart';

class ApicultoresPageWidget extends StatefulWidget {
  const ApicultoresPageWidget({super.key});

  @override
  State<ApicultoresPageWidget> createState() => _ApicultoresPageWidgetState();
}

class _ApicultoresPageWidgetState extends State<ApicultoresPageWidget> {
  List<Map<String, dynamic>> _apicultores = [];
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
    final data = await SupabaseService().getApicultores();
    if (mounted) {
      setState(() {
        _apicultores = data;
        _filtered = data;
        _loading = false;
      });
    }
  }

  void _onSearch(String val) {
    setState(() {
      _filtered = _apicultores.where((a) {
        final name = (a['nombre'] ?? '').toString().toLowerCase();
        final loc = (a['localidad'] ?? '').toString().toLowerCase();
        return name.contains(val.toLowerCase()) || loc.contains(val.toLowerCase());
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
          'Directorio de Apicultores',
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
                hintText: 'Buscar por nombre o localidad...',
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
                      final a = _filtered[index];
                      return _buildApicultorCard(a);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildApicultorCard(Map<String, dynamic> a) {
    final nombre = a['nombre'] ?? 'Sin nombre';
    final localidad = a['localidad'] ?? 'Sin localidad';
    final id = a['id']?.toString() ?? '';
    final codigo = a['apicultor_codigo'] ?? (id.length > 6 ? id.substring(0, 6).toUpperCase() : id);

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
            width: 44, height: 44,
            decoration: BoxDecoration(color: kPrimaryContainer, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.person_pin_circle_rounded, color: kSecContainer, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, fontSize: 16, color: kPrimary)),
                Text(localidad, style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant)),
              ],
            ),
          ),
          Text(
            codigo,
            style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 10, color: kPrimary.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  static const kPrimaryContainer = Color(0xFF1E352F);
}
