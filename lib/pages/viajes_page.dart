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

  final List<String> _tabs = ['PLANIFICADOS', 'EN PROCESO', 'TERMINADOS'];
  final List<String> _statusKeys = ['Planificado', 'En Proceso', 'Terminado'];

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
      if (status == 'En Proceso') {
        return vEstado == 'En Proceso' || vEstado == 'En Curso' || vEstado == 'Cargado';
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
          labelStyle: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w600, fontSize: 10, letterSpacing: 0.5),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : TabBarView(
              controller: _tabController,
              children: _statusKeys.map((s) => _buildTripList(s, theme)).toList(),
            ),
    );
  }

  Widget _buildTripList(String status, FlutterFlowTheme theme) {
    final trips = _filtered(status);

    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 48, color: Colors.black12),
            const SizedBox(height: 16),
            Text('No hay viajes en esta sección', style: TextStyle(color: Colors.black45, fontFamily: 'Inter')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchViajes,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: trips.length,
        itemBuilder: (context, index) => _buildTripCard(trips[index], theme),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> v, FlutterFlowTheme theme) {
    final estado = v['estado'] ?? 'Planificado';
    final id = v['id']?.toString() ?? '';
    final codigo = v['viaje_codigo']?.toString() ?? (id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase());
    final vehiculo = v['vehiculo_codigo']?.toString() ?? 'Sin vehículo';
    final fechaRaw = v['fecha'] ?? v['created_at'];
    final fecha = DateTime.tryParse(fechaRaw.toString());
    final fechaStr = fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) : 'S/D';
    final chofer = v['profiles'] ?? {};
    final choferNombre = '${chofer['nombre'] ?? 'Sin'} ${chofer['apellido'] ?? 'Asignar'}';

    Color chipColor;
    Color chipBg;
    Color leftBorder;
    if (estado == 'En Proceso' || estado == 'En Curso' || estado == 'Cargado') {
      chipColor = const Color(0xFF7D5700);
      chipBg = const Color(0xFFFDEFCC);
      leftBorder = const Color(0xFFFDBE49);
    } else if (estado == 'Terminado' || estado == 'Finalizado') {
      chipColor = const Color(0xFF1A6B43);
      chipBg = const Color(0xFFD4F0E1);
      leftBorder = const Color(0xFF249689);
    } else {
      chipColor = const Color(0xFF1565C0);
      chipBg = const Color(0xFFD6E4FF);
      leftBorder = const Color(0xFF1565C0);
    }
    
    return GestureDetector(
      onTap: () => context.push('/viajedetalle?viajeId=$id'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: leftBorder,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehiculo,
                                style: TextStyle(
                                  fontFamily: 'Work Sans',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                  color: Colors.black45,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                codigo,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Color(0xFF08201A),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              estado.toUpperCase(),
                              style: TextStyle(color: chipColor, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Work Sans'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.black45),
                          const SizedBox(width: 6),
                          Text(fechaStr, style: const TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'Inter')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 14, color: Colors.black45),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Chofer: $choferNombre',
                              style: const TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'Inter'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'VER DETALLE',
                              style: TextStyle(
                                color: Color(0xFF08201A),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                fontFamily: 'Work Sans',
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF08201A)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
