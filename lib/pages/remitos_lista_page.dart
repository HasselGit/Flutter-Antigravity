import '../flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RemitosListaPageWidget extends StatefulWidget {
  const RemitosListaPageWidget({super.key});

  @override
  State<RemitosListaPageWidget> createState() => _RemitosListaPageWidgetState();
}

class _RemitosListaPageWidgetState extends State<RemitosListaPageWidget> {
  List<Map<String, dynamic>> _remitos = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  // Design system constants


  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final data = await SupabaseService().getRemitos();
    if (mounted) {
      setState(() {
        _remitos = data;
        _filtered = data;
        _loading = false;
      });
    }
  }

  void _onSearch(String val) {
    setState(() {
      _filtered = _remitos.where((r) {
        final apicultor = (r['apicultores']?['nombre'] ?? '').toString().toLowerCase();
        final fecha = DateFormat('dd/MM/yyyy').format(DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now()).toLowerCase();
        return apicultor.contains(val.toLowerCase()) || fecha.contains(val.toLowerCase());
      }).toList();
    });
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
          'Remitos Digitales',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: DesignTokens.primary),
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
                hintText: 'Buscar apicultor o fecha...',
                prefixIcon: const Icon(Icons.search, color: DesignTokens.primary),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final r = _filtered[index];
                      return _buildRemitoCard(r);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemitoCard(Map<String, dynamic> r) {
    final numero = r['numero_remito'] ?? '0000-0000';
    final apicultor = r['apicultores']?['nombre'] ?? 'S/D';
    final fecha = DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now();
    final fechaStr = DateFormat('dd/MM/yyyy HH:mm').format(fecha);
    final solicitud = r['solicitudes']?['solicitud_codigo'] ?? 'S/C';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: DesignTokens.primary.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('N° $numero', style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, fontSize: 16, color: DesignTokens.primary)),
                Text(apicultor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DesignTokens.onSurfaceVariant)),
                Text('Fecha: $fechaStr', style: const TextStyle(fontSize: 11, color: DesignTokens.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(solicitud, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
              const SizedBox(height: 4),
              const Icon(Icons.open_in_new_rounded, size: 16, color: DesignTokens.primary),
            ],
          ),
        ],
      ),
    );
  }
}
