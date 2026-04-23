import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'Home';
  static String routePath = '/home';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E352F),
        elevation: 0,
        toolbarHeight: 64,
        title: Text(
          'GeoLogística',
          style: GoogleFonts.interTight(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFFC68E17),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), label: 'Viajes'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Rutas'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Centro de Control',
            style: GoogleFonts.interTight(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E352F),
            ),
          ),
          const SizedBox(height: 24),
          // Grid of Main Functions
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildMenuCard('Distribuciones', Icons.reorder, const Color(0xFF4A5D23)),
              _buildMenuCard('Recolecciones', Icons.assignment_return_outlined, const Color(0xFF1E352F)),
              _buildMenuCard('Viajes', Icons.alt_route, const Color(0xFFC68E17), () => context.push('/viajes')),
              _buildMenuCard('Rutas', Icons.location_on_outlined, const Color(0xFF4A5D23), () => context.push('/rutas')),
            ],
          ),
          const SizedBox(height: 30),
          _buildSectionTitle('Estado de Viajes'),
          const SizedBox(height: 16),
          _buildStatusRow(),
        ],
      ),
    );
  }

  Widget _buildMenuCard(String title, IconData icon, Color color, [VoidCallback? onTap]) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E352F)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.interTight(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E352F)),
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        _buildStatusChip('Planificados', Colors.blue),
        const SizedBox(width: 8),
        _buildStatusChip('En curso', Colors.green),
        const SizedBox(width: 8),
        _buildStatusChip('Terminados', Colors.grey),
      ],
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1E352F)),
            child: Center(
              child: Image.asset('assets/images/logo_Geologistica_Verde.png', height: 80),
            ),
          ),
          _buildDrawerItem(Icons.group_outlined, 'Apicultores'),
          _buildDrawerItem(Icons.location_city_outlined, 'Localidades'),
          _buildDrawerItem(Icons.scale_outlined, 'Pesajes'),
          const Divider(),
          _buildDrawerItem(Icons.settings_outlined, 'Configuración'),
          const Spacer(),
          _buildDrawerItem(Icons.logout, 'Cerrar Sesión', isLogout: true),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, {bool isLogout = false}) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.red : const Color(0xFF1E352F)),
      title: Text(
        title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: isLogout ? Colors.red : const Color(0xFF1E352F)),
      ),
      onTap: () async {
        if (isLogout) {
          await Supabase.instance.client.auth.signOut();
          if (mounted) context.go('/');
        }
      },
    );
  }
}
