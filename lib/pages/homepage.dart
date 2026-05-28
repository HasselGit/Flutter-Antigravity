import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'Home';
  static String routePath = '/home';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  Map<String, int> _stats = {'planificados': 0, 'en_curso': 0, 'terminados': 0};
  Map<String, int> _cargasStats = {'planificadas': 0, 'en_curso': 0, 'terminadas': 0};
  bool _loadingStats = true;
  String? _userName;
  String? _userRole;
  String? _userEmail;

  // Stitch exact colors are now in DesignTokens

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nombre = prefs.getString('user_nombre') ?? '';
      final apellido = prefs.getString('user_apellido') ?? '';
      
      if (mounted) {
        setState(() {
          _userName = '$nombre $apellido'.trim();
          _userRole = prefs.getString('user_puesto');
          _userEmail = prefs.getString('user_email');
        });
      }

      final userId = prefs.getString('user_id');
      print('HomePage: Obteniendo stats para $_userRole ($userId)');
      
      final stats = await SupabaseService().getStats(userId: userId, role: _userRole);
      final cargasStats = await SupabaseService().getCargasStats(userId: userId, role: _userRole);

      if (mounted) {
        setState(() {
          _stats = stats;
          _cargasStats = cargasStats;
          _loadingStats = false;
        });
      }
    } catch (e) {
      print('HomePage: Error en _fetchData: $e');
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  String get _displayName => _userName?.isNotEmpty == true ? _userName! : 'Usuario';
  
  String _normalizeRole(String? role) {
    if (role == null) return '';
    return role.toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
  }

  bool get _isAdmin => _userEmail == 'hassel00@gmail.com' || _normalizeRole(_userRole).contains('admin') || Supabase.instance.client.auth.currentUser?.email == 'hassel00@gmail.com';

  bool get _isDeposito {
    final r = _normalizeRole(_userRole);
    final email = (_userEmail ?? '').toLowerCase();
    return r.contains('deposito') || email.contains('cmerlo') || email.contains('csantana');
  }

  bool get _isManagement {
    final r = _normalizeRole(_userRole);
    final email = (_userEmail ?? '').toLowerCase();
    return r.contains('compras') || 
           r.contains('gerente') || 
           r.contains('gerencia') || 
           r.contains('ceo') || 
           r.contains('director') || 
           _isAdmin || 
           email.contains('hespinosa') || 
           email.contains('mparedes') || 
           email.contains('gparedes') || 
           email.contains('lcastellanos') || 
           email.contains('rsteierd');
  }

  bool get _isChofer {
    final r = _normalizeRole(_userRole);
    final email = (_userEmail ?? '').toLowerCase();
    return r.contains('chofer') || email.contains('mperez') || email.contains('cmuse') || email.contains('agomez') || email.contains('efernandez');
  }

  String get _initials {
    final parts = _displayName.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: DesignTokens.primary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/logo_Geologistica_Verde.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GeoLogística',
                  style: DesignTokens.headlineStyle().copyWith(fontSize: 16),
                ),
                Text(
                  'APIARY LOGISTICS',
                  style: DesignTokens.labelStyle().copyWith(fontSize: 8, color: DesignTokens.primary.withOpacity(0.4), letterSpacing: 1),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(shape: BoxShape.circle, color: DesignTokens.primary, border: Border.all(color: DesignTokens.secondary, width: 1.5)),
              child: Text(_initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ──────────────────────────────────────────────────────────
          // LIGHT AppBar — Stitch style: cream bg, dark green text
          // ──────────────────────────────────────────────────────────


          // Body
          Expanded(
            child: RefreshIndicator(
              color: DesignTokens.secondary,
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Text(
                      'Bienvenido,',
                      style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant),
                    ),
                    Text(
                      _displayName,
                      style: DesignTokens.headlineStyle().copyWith(fontSize: 26, letterSpacing: -0.5),
                    ),

                    const SizedBox(height: 24),

                    // ── Stats row Viajes ──
                    if (!_isDeposito) ...[
                      Text('ESTADO DE VIAJES', style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _statCard('PENDIENTE', _stats['planificados']!, const Color(0xFF1565C0), const Color(0xFFD6E4FF), onTap: () => context.push('/viajes?estado=Pendiente')),
                          const SizedBox(width: 10),
                          _statCard('EN CURSO', _stats['en_curso']!, const Color(0xFF7D5700), const Color(0xFFFDEFCC), onTap: () => context.push('/viajes?estado=En%20Curso')),
                          const SizedBox(width: 10),
                          _statCard('TERMINADOS', _stats['terminados']!, const Color(0xFF1A6B43), const Color(0xFFD4F0E1), onTap: () => context.push('/viajes?estado=Terminado')),
                        ],
                      ),
                      const SizedBox(height: 28),
                    ],

                    // ── Stats row Cargas ──
                    if (_isDeposito) ...[
                      Text('ESTADO DE CARGAS', style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _statCard('PENDIENTES', _cargasStats['planificadas']!, const Color(0xFF1565C0), const Color(0xFFD6E4FF), onTap: () => context.push('/depositoHome?tab=0')),
                          const SizedBox(width: 10),
                          _statCard('EN CURSO', _cargasStats['en_curso']!, const Color(0xFF7D5700), const Color(0xFFFDEFCC), onTap: () => context.push('/depositoHome?tab=1')),
                          const SizedBox(width: 10),
                          _statCard('TERMINADAS', _cargasStats['terminadas']!, const Color(0xFF1A6B43), const Color(0xFFD4F0E1), onTap: () => context.push('/depositoHome?tab=2')),
                        ],
                      ),
                      const SizedBox(height: 28),
                    ],

                    const SizedBox(height: 28),

                    // ── Modules ──
                    Text(
                      'MÓDULOS DE OPERACIÓN',
                      style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11),
                    ),
                    const SizedBox(height: 14),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.05,
                      children: [
                        if (_isChofer || _userRole == null)
                          _moduleCard(
                            icon: Icons.local_shipping_rounded,
                            title: 'Mis Viajes',
                            subtitle: 'Rutas asignadas\ny operaciones',
                            bgColor: DesignTokens.primary,
                            accentColor: DesignTokens.secondary,
                            onTap: () => context.push('/choferHome'),
                          ),
                        if (_isDeposito || _isChofer)
                          _moduleCard(
                            icon: Icons.warehouse_rounded,
                            title: _isDeposito ? 'Depósito' : 'Depósito Huinca',
                            subtitle: 'Cargas y depósito\ncirculante',
                            bgColor: DesignTokens.primary,
                            accentColor: DesignTokens.secondary,
                            onTap: () => context.push('/depositoHome'),
                          ),
                        if (_isAdmin || _isManagement)
                          _moduleCard(
                            icon: Icons.alt_route_rounded,
                            title: 'Gestión de Viajes',
                            subtitle: 'Lista completa\nde rutas y viajes',
                            bgColor: DesignTokens.primary,
                            accentColor: DesignTokens.secondary,
                            onTap: () => context.push('/viajes'),
                          ),
                        if (_isAdmin || _isManagement)
                          _moduleCard(
                            icon: Icons.dashboard_customize_rounded,
                            title: 'Dashboard',
                            subtitle: 'Estadísticas y\nKPIs de gestión',
                            bgColor: DesignTokens.primary,
                            accentColor: DesignTokens.secondary,
                            onTap: () => context.push('/gerenteHome'),
                          ),
                        if (!_isDeposito && (_isManagement && !_normalizeRole(_userRole).contains('ceo') && !_normalizeRole(_userRole).contains('gerente') && !_normalizeRole(_userRole).contains('gerencia')))
                          _moduleCard(
                            icon: Icons.inventory_2_rounded,
                            title: 'Gestión de Cargas',
                            subtitle: 'Preparar cargas\npara viajes',
                            bgColor: DesignTokens.primary,
                            accentColor: DesignTokens.secondary,
                            onTap: () => context.push('/cargas'),
                          ),
                        if (!_isChofer && !_isDeposito) ...[
                          _moduleCard(
                            icon: Icons.assignment_ind_rounded,
                            title: 'Planificador',
                            subtitle: 'Crear rutas y\nasignar choferes',
                            bgColor: DesignTokens.primary,
                            accentColor: DesignTokens.secondary,
                            onTap: () => context.push('/planificarViaje'),
                          ),
                          _moduleCard(
                            icon: Icons.list_alt_rounded,
                            title: 'Solicitudes',
                            subtitle: 'Gestión de carga\ny recolecciones',
                            bgColor: DesignTokens.primary,
                            accentColor: DesignTokens.secondary,
                            onTap: () => context.push('/necesidades'),
                          ),
                        ],
                        if (!_normalizeRole(_userRole).contains('ceo') && !_normalizeRole(_userRole).contains('gerente') && !_normalizeRole(_userRole).contains('gerencia') && !_isDeposito) ...[
                          _moduleCard(
                            icon: Icons.scale_rounded,
                            title: 'Control Pesajes',
                            subtitle: 'Listado de pesajes\ny control de carga',
                            bgColor: DesignTokens.primary,
                            accentColor: DesignTokens.secondary,
                            onTap: () => context.push('/pesajes'),
                          ),
                          _moduleCard(
                            icon: Icons.inventory_2_rounded,
                            title: 'Productos',
                            subtitle: 'Gestión de stock\ne insumos',
                            bgColor: DesignTokens.primary,
                            accentColor: DesignTokens.secondary,
                            onTap: () => context.push('/productos'),
                          ),
                          _moduleCard(
                            icon: Icons.payments_rounded,
                            title: 'Gastos',
                            subtitle: 'Peajes, comida\ny combustible',
                            bgColor: DesignTokens.primary,
                            accentColor: DesignTokens.secondary,
                            onTap: () => context.push('/gastos'),
                          ),
                        ],
                        if (!_isDeposito)
                          _moduleCard(
                            icon: Icons.alt_route_rounded,
                            title: 'Control de Ruta',
                            subtitle: 'Trayectos activos\nen tiempo real',
                            bgColor: DesignTokens.primary,
                            accentColor: DesignTokens.secondary,
                            onTap: () => context.push('/rutas'),
                          ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Quick actions ──
                    Text(
                      'ACCIONES RÁPIDAS',
                      style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11),
                    ),
                    const SizedBox(height: 12),

                    if (!_isDeposito) ...[                      
                      _quickAction(Icons.inventory_2_rounded, 'Inventario de Productos', 'Gestión de stock e insumos', () => context.push('/productos')),
                      const SizedBox(height: 10),
                      _quickAction(Icons.payments_rounded, 'Gestión de Gastos', 'Registro de peajes y combustible', () => context.push('/gastos')),
                      const SizedBox(height: 10),
                      _quickAction(Icons.group_rounded, 'Apicultores', 'Directorio de productores', () => context.push('/apicultores')),
                      const SizedBox(height: 10),
                    ],
                    if (!_isChofer) ...[
                      _quickAction(
                        Icons.map_rounded,
                        'Seguimiento Satelital',
                        'Monitoreo de camiones en tiempo real',
                        () async {
                          // Try forcing the specific Fleet app using Android Intent scheme
                          final intentUrl = Uri.parse('intent://satelital.uninet.com.ar/GpsGateServer/VehicleTracker/VehicleTracker.html?appid=59#Intent;scheme=http;package=com.gpsgate.fleet;end;');
                          final fallbackUrl = Uri.parse('http://satelital.uninet.com.ar/GpsGateServer/VehicleTracker/VehicleTracker.html?appid=59');
                          try {
                            // Intenta abrir el intent (forzando la app Fleet)
                            final launched = await launchUrl(intentUrl, mode: LaunchMode.externalNonBrowserApplication);
                            if (!launched) {
                              // Si falla (ej: iOS o app no instalada), usa el fallback
                              await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
                            }
                          } catch (e) {
                            // Fallback seguro si la plataforma no soporta intent://
                            try {
                              await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
                            } catch (e2) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error al abrir sitio: $e2')),
                                );
                              }
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    _quickAction(Icons.receipt_long_rounded, 'Remitos Digitales', 'Documentos de cierre', () => context.push('/remitosLista')),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _statCard(String label, int value, Color textColor, Color bgColor, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _loadingStats ? '—' : value.toString(),
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Work Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 8,
                  color: textColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moduleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: accentColor),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Colors.white.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DesignTokens.primary.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(color: DesignTokens.primary.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DesignTokens.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: DesignTokens.outline),
              ),
              child: Icon(icon, size: 20, color: DesignTokens.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 14, color: DesignTokens.onSurface)),
                  Text(subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: DesignTokens.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: DesignTokens.primary.withOpacity(0.25)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: DesignTokens.surface,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: DesignTokens.primary),
            child: Row(
              children: [
                ClipOval(child: Image.asset('assets/images/logo_Geologistica_Verde.png', width: 50, height: 50)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_userRole ?? 'Operador', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (_isAdmin || _isManagement)
                  _drawerItem(Icons.dashboard_rounded, 'Dashboard', () => context.push('/gerenteHome')),
                if (_isAdmin || _isManagement)
                  _drawerItem(Icons.alt_route_rounded, 'Gestión de Viajes', () => context.push('/viajes')),
                _drawerItem(Icons.local_shipping_rounded, 'Vehículos', () => context.push('/vehiculos')),
                if (!_isDeposito && !_isChofer) ...[
                  _drawerItem(Icons.inventory_2_rounded, 'Productos', () => context.push('/productos')),
                  _drawerItem(Icons.payments_rounded, 'Gestión de Gastos', () => context.push('/gastos')),
                ],
                _drawerItem(Icons.scale_rounded, 'Control de Pesajes', () => context.push('/pesajes')),
                if (_isDeposito || _isChofer)
                  _drawerItem(Icons.warehouse_rounded, _isDeposito ? 'Cargas Depósito' : 'Cargas Dep. Huinca', () => context.push('/depositoHome')),
                if ((_isAdmin || _isManagement) && !_isDeposito)
                  _drawerItem(Icons.inventory_2_rounded, 'Gestión de Cargas', () => context.push('/cargas')),
                const Divider(),
                if (!_isDeposito)
                  _drawerItem(Icons.group_rounded, 'Apicultores', () => context.push('/apicultores')),
                _drawerItem(Icons.receipt_long_rounded, 'Remitos Digitales', () => context.push('/remitosLista')),
              ],
            ),
          ),
          const Divider(),
          _drawerItem(Icons.logout_rounded, 'Cerrar Sesión', () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) context.go('/');
          }),
          _drawerItem(Icons.power_settings_new_rounded, 'Salir', () {
            SystemNavigator.pop();
          }, color: Colors.redAccent),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? DesignTokens.primary),
      title: Text(title, style: DesignTokens.labelStyle().copyWith(color: color ?? DesignTokens.onSurface)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DesignTokens.primary.withOpacity(0.07))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _navItem(Icons.home_filled, 'HOME', true, () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: active ? DesignTokens.primary : DesignTokens.onSurface.withOpacity(0.3)),
          if (active) ...[
            const SizedBox(width: 8),
            Text(label, style: DesignTokens.labelStyle().copyWith(fontSize: 10, color: DesignTokens.primary, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}
