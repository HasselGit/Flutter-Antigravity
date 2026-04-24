import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'Home';
  static String routePath = '/home';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  Map<String, int> _stats = {'planificados': 0, 'en_curso': 0, 'terminados': 0};
  bool _loadingStats = true;
  String? _userName;
  String? _userRole;
  String? _userEmail;

  // Stitch exact colors
  static const Color kPrimary = Color(0xFF08201A);
  static const Color kPrimaryContainer = Color(0xFF1E352F);
  static const Color kSecondaryContainer = Color(0xFFFDBE49);
  static const Color kSurface = Color(0xFFFBF9F8);
  static const Color kSurfaceLow = Color(0xFFF5F3F3);
  static const Color kOnSurface = Color(0xFF1B1C1C);
  static const Color kOnSurfaceVariant = Color(0xFF424846);
  static const Color kOutlineVariant = Color(0xFFC2C8C4);

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

      final data = await Supabase.instance.client
          .from('viajes')
          .select('estado');

      int planificados = 0, enCurso = 0, terminados = 0;
      for (final v in data) {
        final e = v['estado'] ?? '';
        if (e == 'Planificado') planificados++;
        else if (e == 'En Curso') enCurso++;
        else if (e == 'Terminado') terminados++;
      }
      if (mounted) {
        setState(() {
          _stats = {'planificados': planificados, 'en_curso': enCurso, 'terminados': terminados};
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  String get _displayName => _userName?.isNotEmpty == true ? _userName! : 'Usuario';
  String get _initials {
    final parts = _displayName.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: Column(
        children: [
          // ──────────────────────────────────────────────────────────
          // LIGHT AppBar — Stitch style: cream bg, dark green text
          // ──────────────────────────────────────────────────────────
          Container(
            color: kSurface,
            child: SafeArea(
              bottom: false,
              child: Container(
                decoration: BoxDecoration(
                  color: kSurface,
                  border: Border(
                    bottom: BorderSide(color: kPrimary.withOpacity(0.08), width: 1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  child: Row(
                    children: [
                      // Logo
                      ClipOval(
                        child: Image.asset(
                          'assets/images/logo_Geologistica_Verde.png',
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GeoLogística',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: kPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'APIARY LOGISTICS',
                              style: TextStyle(
                                fontFamily: 'Work Sans',
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                                color: kPrimary.withOpacity(0.45),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Avatar
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kPrimaryContainer,
                          border: Border.all(color: kSecondaryContainer, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            _initials,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Logout
                      GestureDetector(
                        onTap: () async {
                          await Supabase.instance.client.auth.signOut();
                          if (context.mounted) context.go('/');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kSurfaceLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kOutlineVariant),
                          ),
                          child: Icon(Icons.logout_rounded, color: kPrimary.withOpacity(0.6), size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Body
          Expanded(
            child: RefreshIndicator(
              color: kSecondaryContainer,
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
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: kOnSurfaceVariant,
                      ),
                    ),
                    Text(
                      _displayName,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        color: kPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Stats row ──
                    Row(
                      children: [
                        _statCard('PLANIFICADOS', _stats['planificados']!, const Color(0xFF1565C0), const Color(0xFFD6E4FF)),
                        const SizedBox(width: 10),
                        _statCard('EN CURSO', _stats['en_curso']!, const Color(0xFF7D5700), const Color(0xFFFDEFCC)),
                        const SizedBox(width: 10),
                        _statCard('TERMINADOS', _stats['terminados']!, const Color(0xFF1A6B43), const Color(0xFFD4F0E1)),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Modules ──
                    const Text(
                      'MÓDULOS DE OPERACIÓN',
                      style: TextStyle(
                        fontFamily: 'Work Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: kOnSurfaceVariant,
                        letterSpacing: 1.1,
                      ),
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
                        _moduleCard(
                          icon: Icons.local_shipping_rounded,
                          title: (_userRole == 'Chofer') ? 'Mis Viajes' : 'Control de Viajes',
                          subtitle: (_userRole == 'Chofer') ? 'Rutas asignadas\ny operaciones' : 'Gestión y estado\nglobal de rutas',
                          bgColor: kPrimary,
                          accentColor: kSecondaryContainer,
                          onTap: () => context.push('/viajes'),
                        ),
                        _moduleCard(
                          icon: Icons.alt_route_rounded,
                          title: 'Control de Ruta',
                          subtitle: 'Trayectos activos\nen tiempo real',
                          bgColor: kPrimary,
                          accentColor: kSecondaryContainer,
                          onTap: () => context.push('/rutas'),
                        ),
                        _moduleCard(
                          icon: Icons.scale_rounded,
                          title: 'Recolecciones',
                          subtitle: 'Pesajes SENASA\ny tambores',
                          bgColor: kPrimary,
                          accentColor: kSecondaryContainer,
                          onTap: () => context.push('/viajes'),
                        ),
                        _moduleCard(
                          icon: Icons.inventory_2_rounded,
                          title: 'Distribución',
                          subtitle: 'Entregas y\nremitos digitales',
                          bgColor: kPrimary,
                          accentColor: kSecondaryContainer,
                          onTap: () => context.push('/viajes'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Quick actions ──
                    const Text(
                      'ACCIONES RÁPIDAS',
                      style: TextStyle(
                        fontFamily: 'Work Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: kOnSurfaceVariant,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _quickAction(Icons.map_rounded, 'Ver Mapa de Rutas', 'Rutas activas en tiempo real', () {}),
                    const SizedBox(height: 10),
                    _quickAction(Icons.group_rounded, 'Apicultores', 'Directorio de productores', () {}),
                    const SizedBox(height: 10),
                    _quickAction(Icons.receipt_long_rounded, 'Remitos Digitales', 'Documentos de cierre', () {}),

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

  Widget _statCard(String label, int value, Color textColor, Color bgColor) {
    return Expanded(
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
          border: Border.all(color: kPrimary.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(color: kPrimary.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kSurfaceLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kOutlineVariant),
              ),
              child: Icon(icon, size: 20, color: kPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 14, color: kOnSurface)),
                  Text(subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: kOnSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: kPrimary.withOpacity(0.25)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kPrimary.withOpacity(0.07))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.dashboard_rounded, 'INICIO', true, () {}),
              _navItem(Icons.local_shipping_rounded, 'VIAJES', false, () => context.push('/viajes')),
              _navItem(Icons.alt_route_rounded, 'RUTAS', false, () => context.push('/rutas')),
              _navItem(Icons.person_rounded, 'PERFIL', false, () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: active ? kPrimaryContainer.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: active ? kPrimaryContainer : kOnSurface.withOpacity(0.35),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Work Sans',
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              fontSize: 9,
              color: active ? kPrimaryContainer : kOnSurface.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }
}
