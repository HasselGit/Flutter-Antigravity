import '../flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase_service.dart';

class DistribucionesPageWidget extends StatefulWidget {
  const DistribucionesPageWidget({super.key});

  static String routeName = 'Distribuciones';
  static String routePath = '/distribuciones';

  @override
  State<DistribucionesPageWidget> createState() => _DistribucionesPageWidgetState();
}

class _DistribucionesPageWidgetState extends State<DistribucionesPageWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _viajes = [];
  bool _loading = true;
  String? _error;
  String? _userRole;

  final List<String> _tabs = ['PLANIFICADAS', 'EN CURSO', 'TERMINADAS'];
  final List<String> _statusKeys = ['Planificado', 'En Curso', 'Terminado'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchDistribuciones();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDistribuciones() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_puesto');
      if (mounted) setState(() => _userRole = userRole);
      final userId = prefs.getString('user_id');

      final data = await SupabaseService().getViajes(userId: userId, role: userRole);
      
      final filtered = data.where((v) {
        final paradas = (v['paradas'] as List?) ?? [];
        return paradas.any((p) => (p['tipo'] ?? p['tipo_operacion'] ?? '').toString().toLowerCase().contains('distribuc'));
      }).toList();

      if (mounted) setState(() { 
        _viajes = filtered;
        _loading = false; 
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> _filtered(String status) {
    return _viajes.where((v) {
      final vEstado = (v['estado'] ?? '').toString();
      if (status == 'En Curso' && vEstado == 'En Proceso') return true;
      return vEstado == status;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFF08201A);
    const kSecContainer = Color(0xFFFDBE49);
    const kSurface = Color(0xFFFBF9F8);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F3),
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kPrimary),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Distribución de Insumos',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: kPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: kPrimary),
            onPressed: _fetchDistribuciones,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: TabBar(
            controller: _tabController,
            indicatorColor: kSecContainer,
            indicatorWeight: 3,
            labelColor: kPrimary,
            unselectedLabelColor: kPrimary.withOpacity(0.4),
            labelStyle: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8),
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kSecContainer))
          : TabBarView(
              controller: _tabController,
              children: _statusKeys.map((s) => _buildTripList(s)).toList(),
            ),
    );
  }

  Widget _buildTripList(String status) {
    final trips = _filtered(status);
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_rounded, size: 48, color: const Color(0xFF08201A).withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('No hay distribuciones $status', style: const TextStyle(color: Color(0xFF424846))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: trips.length,
      itemBuilder: (context, index) => _buildTripCard(trips[index]),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> v) {
    final theme = FlutterFlowTheme.of(context);
    final estado = v['estado'] ?? 'Planificado';
    final id = v['id']?.toString() ?? '';
    final displayId = v['viaje_codigo'] ?? id.substring(0, 8).toUpperCase();
    
    final paradas = (v['paradas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    int itemsCount = 0;
    for (final p in paradas) {
      if ((p['tipo'] ?? p['tipo_operacion'] ?? '').toString().toLowerCase().contains('distribuc')) {
        final items = (p['parada_items'] as List?) ?? [];
        itemsCount += items.length;
      }
    }

    return GestureDetector(
      onTap: () => context.push('/viajedetalle?viajeId=$id'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(displayId, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF08201A))),
                Text(estado.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF424846)),
                const SizedBox(width: 8),
                Text('Items a Entregar: $itemsCount', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('VER DETALLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.secondary)),
                const Icon(Icons.chevron_right, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
