import 'package:flutter/material.dart';
import 'package:geo_logistica/backend/supabase_service.dart';
import 'package:geo_logistica/flutter_flow/flutter_flow_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';

class RutaDetalleWidget extends StatefulWidget {
  final String viajeId;
  const RutaDetalleWidget({super.key, required this.viajeId});

  @override
  State<RutaDetalleWidget> createState() => _RutaDetalleWidgetState();
}

class _RutaDetalleWidgetState extends State<RutaDetalleWidget> {
  Map<String, dynamic>? _ruta;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService().getViajeDetalle(widget.viajeId);
      setState(() => _ruta = data);
    } catch (e) {
      print('Error cargando ruta: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_ruta == null) return const Scaffold(body: Center(child: Text('No se encontró la ruta')));

    final paradas = List<Map<String, dynamic>>.from(_ruta!['paradas'] ?? []);

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8), // Crema Stitch
      appBar: AppBar(
        title: Text('Plan Logístico: ${_ruta!['viaje_codigo']}', style: theme.headlineSmall),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.primary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // INFO DE PLANIFICACIÓN
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E352F),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.route, color: Color(0xFFFDBE49), size: 30),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL NODOS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text('${paradas.length} Paradas', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Text('SECUENCIA DE NODOS', style: theme.titleSmall),
            const SizedBox(height: 16),

            if (paradas.isEmpty)
              _buildEmptyState(theme)
            else
              ...paradas.map((p) => _buildNodoItem(p, theme)).toList(),

            const SizedBox(height: 32),

            // BOTÓN DE MAPA DE NODOS
            if (paradas.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('VER NODOS EN MAPA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E352F),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFC68E17), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _openMap(paradas),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(FlutterFlowTheme theme) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.add_location_alt_outlined, size: 60, color: theme.primary.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('Esta ruta aún no tiene nodos asignados.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.push('/planificarViaje?editId=${widget.viajeId}'),
            style: ElevatedButton.styleFrom(backgroundColor: theme.secondary, foregroundColor: theme.primary),
            child: const Text('PLANIFICAR AHORA'),
          ),
        ],
      ),
    );
  }

  Widget _buildNodoItem(Map<String, dynamic> p, FlutterFlowTheme theme) {
    final items = List<Map<String, dynamic>>.from(p['parada_items'] ?? []);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LINEA DE TIEMPO / SECUENCIA
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Color(0xFF08201A), shape: BoxShape.circle),
                child: Center(child: Text('${p['orden_secuencia']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              ),
              Expanded(child: Container(width: 2, color: const Color(0xFF08201A).withOpacity(0.1))),
            ],
          ),
          const SizedBox(width: 16),
          // CONTENIDO DEL NODO
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p['ubicacion'] ?? 'S/N', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      Text(p['tipo_operacion']?.toUpperCase() ?? 'OP', style: const TextStyle(color: Color(0xFFC68E17), fontWeight: FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                  Text(p['localidad'] ?? 'S/D', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const Divider(height: 20),
                  if (items.isNotEmpty) ...[
                    const Text('REQUERIMIENTOS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 4),
                    ...items.map((it) => Text('• ${it['producto_codigo']}: ${it['cantidad']} ${it['unidad']}', style: const TextStyle(fontSize: 12))),
                  ] else
                    const Text('Sin requerimientos específicos', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openMap(List<Map<String, dynamic>> paradas) async {
    final localities = paradas.map((p) => p['localidad']).where((l) => l != null).join('|');
    final url = 'https://www.google.com/maps/dir/?api=1&origin=General+Pico&destination=General+Pico&waypoints=$localities&travelmode=driving';
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }
}
