import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';

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
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        title: Text('Dashboard Gerencial', style: DesignTokens.headlineStyle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: DesignTokens.primary),
            onPressed: _fetchStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: DesignTokens.primary),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: DesignTokens.primary))
        : RefreshIndicator(
            onRefresh: _fetchStats,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryGrid(),
                  const SizedBox(height: 32),
                  Text('VIAJES EN CURSO', style: DesignTokens.labelStyle()),
                  const SizedBox(height: 12),
                  if (_viajesActivos.isEmpty)
                    _buildEmptyState()
                  else
                    ..._viajesActivos.map((v) => _buildViajeCard(v)).toList(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSummaryGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _statBox('CARGA TOTAL', '${_totalKg.toStringAsFixed(0)} Kg', Icons.scale_rounded, DesignTokens.primary),
        _statBox('VIAJES HOY', _viajesEnCurso.toString(), Icons.local_shipping_rounded, DesignTokens.secondary),
        _statBox('STOCK TAMBORES', _tamboresStock.toString(), Icons.inventory_2_rounded, Colors.blueGrey),
        _statBox('NOTIFICACIONES', '0', Icons.notifications_active_rounded, Colors.orange),
      ],
    );
  }

  Widget _statBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 20, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black45, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViajeCard(Map<String, dynamic> v) {
    final chofer = v['profiles'] ?? {};
    final choferName = chofer['nombre'] != null ? '${chofer['nombre']} ${chofer['apellido']}' : 'Sin Asignar';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(v['viaje_codigo'] ?? 'V-000', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(v['estado'] ?? 'EN CURSO', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: DesignTokens.secondary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(choferName, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(v['descripcion'] ?? 'Sin descripción', style: const TextStyle(fontSize: 12, color: Colors.black38)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(Icons.no_transfer_rounded, size: 48, color: DesignTokens.primary.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('No hay viajes activos', style: TextStyle(color: Colors.black38)),
        ],
      ),
    );
  }
}
