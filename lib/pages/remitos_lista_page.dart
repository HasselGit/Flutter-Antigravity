import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;

class RemitosListaPageWidget extends StatefulWidget {
  const RemitosListaPageWidget({super.key});

  @override
  State<RemitosListaPageWidget> createState() => _RemitosListaPageWidgetState();
}

class _RemitosListaPageWidgetState extends State<RemitosListaPageWidget> {
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _remitos = [];
  List<Map<String, dynamic>> _filtered = [];
  String _activeFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      // Mock data for UI representation if DB is empty
      final data = await SupabaseService().getRemitos();
      if (mounted) {
        setState(() {
          _remitos = data;
          _filtered = data;
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DesignTokens.primary, size: 20),
          onPressed: () => context.go('/home'),
        ),
        centerTitle: false,
        title: Text('Remitos PDF', style: DesignTokens.headlineStyle()),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Gestión y control de documentación de carga.', style: DesignTokens.bodyStyle().copyWith(color: Colors.black38, fontSize: 14)),
          ),
          const SizedBox(height: 24),
          _buildSearchAndFilter(),
          const SizedBox(height: 24),
          _buildFilterChips(),
          const SizedBox(height: 24),
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
              : _filtered.isEmpty 
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) => _buildRemitoCard(_filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _applyFilters(),
                decoration: const InputDecoration(
                  hintText: 'Buscar por Productor o ID...',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.black26),
                  prefixIcon: Icon(Icons.search, size: 20, color: Colors.black26),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 48, width: 48,
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.tune_rounded, color: Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final chips = ['Todos', 'Recolecciones', 'Distribuciones', 'Esta Semana'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: chips.map((c) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ChoiceChip(
            label: Text(c),
            selected: _activeFilter == c,
            onSelected: (val) {
              setState(() {
                _activeFilter = c;
                _applyFilters();
              });
            },
            selectedColor: const Color(0xFF1E302C),
            labelStyle: TextStyle(
              color: _activeFilter == c ? Colors.white : Colors.black38,
              fontWeight: FontWeight.bold,
              fontSize: 12
            ),
            backgroundColor: const Color(0xFFF5F5F5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        )).toList(),
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _filtered = _remitos.where((r) {
        final matchesSearch = _searchController.text.isEmpty || 
          (r['apicultores']?['nombre'] ?? '').toString().toLowerCase().contains(_searchController.text.toLowerCase()) ||
          (r['remito_codigo'] ?? '').toString().toLowerCase().contains(_searchController.text.toLowerCase());
        
        if (_activeFilter == 'Todos') return matchesSearch;
        if (_activeFilter == 'Recolecciones') return matchesSearch && (r['tipo']?.toString().toLowerCase().contains('recolección') ?? false);
        if (_activeFilter == 'Distribuciones') return matchesSearch && (r['tipo']?.toString().toLowerCase().contains('distribución') ?? false);
        return matchesSearch;
      }).toList();
    });
  }

  Widget _buildRemitoCard(Map<String, dynamic> r) {
    final status = r['estado'] ?? 'PENDIENTE';
    final isSigned = status == 'FIRMADO';
    final statusColor = isSigned ? const Color(0xFF4CAF50) : const Color(0xFFFFC107);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFDF7E7), borderRadius: BorderRadius.circular(8)),
                child: Text('ID: ${r['remito_codigo'] ?? 'V-2024-000'}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC68E17))),
              ),
              Row(
                children: [
                  CircleAvatar(radius: 3, backgroundColor: statusColor),
                  const SizedBox(width: 6),
                  Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(r['apicultores']?['nombre'] ?? 'Apicultor S/D', style: DesignTokens.headlineStyle().copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildCardInfo(Icons.local_shipping_outlined, 'TIPO', r['tipo'] ?? 'Entrega Cera'),
              const Spacer(),
              _buildCardInfo(Icons.scale_outlined, 'PESO NETO', '${r['peso_neto'] ?? '0'} kg'),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, color: Color(0xFFF5F5F5)),
          ),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.black26),
              const SizedBox(width: 8),
              Text(DateFormat('dd MMM yyyy • HH:mm').format(DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now()), 
                style: const TextStyle(fontSize: 12, color: Colors.black38)),
              const Spacer(),
              _buildCircleButton(Icons.download_outlined, onTap: () async {
                final url = r['pdf_url'];
                if (url != null) {
                  final resp = await http.get(Uri.parse(url));
                  await Printing.sharePdf(bytes: resp.bodyBytes, filename: 'Remito_${r['remito_codigo']}.pdf');
                }
              }),
              const SizedBox(width: 12),
              _buildTextButton('VER PDF', onTap: () async {
                final url = r['pdf_url'];
                if (url != null) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL del PDF no disponible')));
                }
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black38),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black38)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF424846))),
          ],
        ),
      ],
    );
  }

  Widget _buildCircleButton(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: Colors.black38),
      ),
    );
  }

  Widget _buildTextButton(String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF1E302C), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description_outlined, size: 48, color: Colors.black12),
          const SizedBox(height: 16),
          Text('No hay remitos disponibles', style: DesignTokens.bodyStyle().copyWith(color: Colors.black38)),
        ],
      ),
    );
  }


}
