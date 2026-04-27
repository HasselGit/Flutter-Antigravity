import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../backend/supabase_service.dart';

class GerenteHomeWidget extends StatefulWidget {
  const GerenteHomeWidget({super.key});

  @override
  State<GerenteHomeWidget> createState() => _GerenteHomeWidgetState();
}

class _GerenteHomeWidgetState extends State<GerenteHomeWidget> {
  bool _loading = true;
  double _totalKg = 0;
  int _viajesEnCurso = 0;
  int _tamboresStock = 0;
  List<Map<String, dynamic>> _viajesActivos = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    try {
      final stats = await SupabaseService().getGerenteStats();
      
      if (mounted) {
        setState(() {
          _totalKg = stats['totalKg'];
          _viajesEnCurso = stats['viajesEnCurso'];
          _viajesActivos = stats['viajesActivos'];
          _tamboresStock = stats['tamboresStock'];
          _loading = false;
        });
      }
    } catch (e) {
      print('GerenteHome: Error en _fetchStats: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F8),
        elevation: 0,
        title: const Text('Dashboard Gerencial', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, color: Color(0xFF08201A))),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF08201A)),
            onPressed: _fetchStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF08201A)),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF08201A)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('KPIs Logísticos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF08201A))),
                const SizedBox(height: 16),
                
                // KPI Cards
                Row(
                  children: [
                    Expanded(child: _kpiCard('Miel Recolectada', '${(_totalKg/1000).toStringAsFixed(1)} Tn', Icons.scale_rounded, const Color(0xFF08201A))),
                    const SizedBox(width: 12),
                    Expanded(child: _kpiCard('Viajes Activos', '$_viajesEnCurso', Icons.local_shipping_rounded, const Color(0xFFFDBE49))),
                  ],
                ),
                const SizedBox(height: 12),
                _kpiCard('Tambores en Stock', '$_tamboresStock Unidades', Icons.inventory_2_rounded, const Color(0xFF1E352F), fullWidth: true),
                
                const SizedBox(height: 32),
                
                const Text('Viajes en Curso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF08201A))),
                const SizedBox(height: 12),
                
                if (_viajesActivos.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No hay viajes activos en este momento.')))
                else
                  ..._viajesActivos.map((v) => _viajeCard(v)),
                
                const SizedBox(height: 32),
                
                const Text('Acciones Rápidas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF08201A))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _actionButton('PLANIFICAR', Icons.map_rounded, () => context.push('/planificarViaje'))),
                    const SizedBox(width: 12),
                    Expanded(child: _actionButton('NECESIDADES', Icons.list_alt_rounded, () => context.push('/necesidades'))),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color == const Color(0xFFFDBE49) ? Colors.black : Colors.white, size: 28),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color == const Color(0xFFFDBE49) ? Colors.black : Colors.white)),
          Text(title, style: TextStyle(fontSize: 12, color: (color == const Color(0xFFFDBE49) ? Colors.black : Colors.white).withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _viajeCard(Map<String, dynamic> v) {
    final chofer = v['profiles'] ?? {};
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF08201A).withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(v['viaje_codigo'] ?? 'S/C', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Chofer: ${chofer['nombre']} ${chofer['apellido']} • Vehículo: ${v['vehiculo_codigo']}'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/viajedetalle?viajeId=${v['id']}'),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF08201A),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFF08201A).withOpacity(0.1))),
        elevation: 0,
      ),
    );
  }
}
