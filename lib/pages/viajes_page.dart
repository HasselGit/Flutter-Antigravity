import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase_service.dart';
import 'package:intl/intl.dart';

class ViajesPageWidget extends StatefulWidget {
  const ViajesPageWidget({super.key});

  static String routeName = 'Viajes';
  static String routePath = '/viajes';

  @override
  State<ViajesPageWidget> createState() => _ViajesPageWidgetState();
}

class _ViajesPageWidgetState extends State<ViajesPageWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _viajes = [];
  bool _loading = true;
  String? _error;
  String? _userRole;

  final List<String> _tabs = ['PLANIFICADOS', 'EN CURSO', 'TERMINADOS'];
  final List<String> _statusKeys = ['Planificado', 'En Curso', 'Terminado'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchViajes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchViajes() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_puesto');
      if (mounted) setState(() => _userRole = userRole);
      final userId = prefs.getString('user_id');
      print('ViajesPage: Iniciando fetch para role: $userRole, userId: $userId');

      final data = await SupabaseService().getViajes(userId: userId, role: userRole);
      
      if (mounted) setState(() { 
        _viajes = data;
        _loading = false; 
      });
    } catch (e) {
      print('ViajesPage: Error en _fetchViajes: $e');
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> _filtered(String status) {
    return _viajes.where((v) {
      final vEstado = (v['estado'] ?? '').toString();
      if (status == 'Planificado') return vEstado == 'Planificado';
      if (status == 'En Curso') {
        return vEstado == 'En Curso' || vEstado == 'En Proceso' || vEstado == 'Cargado';
      }
      if (status == 'Terminado') {
        return vEstado == 'Terminado' || vEstado == 'Finalizado' || vEstado == 'Entregado';
      }
      return vEstado == status;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

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
        title: Text(
          _userRole == 'Chofer' ? 'Mis Viajes' : 'Control de Viajes',
          style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 17, color: kPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: kPrimary),
            onPressed: _fetchViajes,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kSecContainer,
          labelColor: kPrimary,
          unselectedLabelColor: kPrimary.withOpacity(0.4),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : TabBarView(
              controller: _tabController,
              children: _statusKeys.map((s) => _buildTripList(s)).toList(),
            ),
    );
  }

  Widget _buildTripList(String status) {
    final trips = _filtered(status);

    if (trips.isEmpty) {
      return Center(child: Text('No hay viajes en esta sección'));
    }

    return RefreshIndicator(
      onRefresh: _fetchViajes,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: trips.length,
        itemBuilder: (context, index) => _buildTripCard(trips[index]),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> v) {
    final estado = v['estado'] ?? 'Planificado';
    final id = v['id']?.toString() ?? '';
    final codigo = v['viaje_codigo'] ?? id.substring(0, 8);
    final fechaRaw = v['fecha'] ?? v['created_at'];
    final fecha = DateTime.tryParse(fechaRaw.toString());
    final fechaStr = fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) : 'S/D';
    final chofer = v['chofer_id'] != null ? 'Chofer ID: ${v['chofer_id']}' : 'Sin chofer';
    
    return GestureDetector(
      onTap: () => context.push('/viajedetalle?viajeId=$id'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(codigo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  _statusChip(estado),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.black45),
                  const SizedBox(width: 6),
                  Text(fechaStr, style: const TextStyle(color: Colors.black45, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person_rounded, size: 14, color: Colors.black45),
                  const SizedBox(width: 6),
                  Text(chofer, style: const TextStyle(color: Colors.black45, fontSize: 12)),
                ],
              ),
              const Divider(height: 24),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('VER DETALLE', style: TextStyle(color: Color(0xFF1E352F), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String estado) {
    Color color = Colors.blue;
    if (estado == 'En Curso' || estado == 'En Proceso') color = Colors.orange;
    if (estado == 'Terminado' || estado == 'Finalizado') color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(estado.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
