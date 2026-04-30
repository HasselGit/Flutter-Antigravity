import 'package:flutter/material.dart';
import 'package:geo_logistica/backend/supabase_service.dart';
import 'package:geo_logistica/flutter_flow/flutter_flow_theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:go_router/go_router.dart';

class ViajeDetalleWidget extends StatefulWidget {
  final String viajeId;
  const ViajeDetalleWidget({super.key, required this.viajeId});

  @override
  State<ViajeDetalleWidget> createState() => _ViajeDetalleWidgetState();
}

class _ViajeDetalleWidgetState extends State<ViajeDetalleWidget> {
  Map<String, dynamic>? _viaje;
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
      setState(() => _viaje = data);
    } catch (e) {
      print('Error cargando detalle: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_viaje == null) return const Scaffold(body: Center(child: Text('No se encontró el viaje')));

    final paradas = List<Map<String, dynamic>>.from(_viaje!['paradas'] ?? []);
    final gastos = List<Map<String, dynamic>>.from(_viaje!['gastos'] ?? []);
    final chofer = _viaje!['chofer'] ?? _viaje!['profiles'] ?? {};
    final choferNombre = (chofer['nombre'] != null) 
        ? '${chofer['nombre']} ${chofer['apellido']}' 
        : 'ID: ${_viaje!['chofer_id'] ?? 'S/D'}';

    final bool esPlanificado = _viaje!['estado'] == 'Planificado';
    final bool tieneRuta = paradas.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        title: Text('Detalle de Viaje: ${_viaje!['viaje_codigo']}', style: theme.headlineSmall),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.primary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CARD DE CABECERA (LOGÍSTICA)
            _buildInfoCard(theme, choferNombre),
            const SizedBox(height: 24),

            // BOTÓN AGREGAR RUTA (Si es planificado y no tiene ruta)
            if (esPlanificado && !tieneRuta)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_road),
                    label: const Text('AGREGAR RUTA Y SOLICITUDES', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.secondary,
                      foregroundColor: theme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    onPressed: () => context.push('/planificarViaje?editId=${widget.viajeId}'),
                  ),
                ),
              ),

            // SECCIÓN: HOJA DE RUTA (NODOS Y REMITOS)
            _buildSectionTitle(theme, 'Operaciones y Documentación', Icons.assignment_outlined),
            if (!tieneRuta)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Pendiente de asignar ruta', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
              )
            else
              ...paradas.map((p) => _buildParadaItem(p, theme)).toList(),
            
            const SizedBox(height: 24),

            // SECCIÓN: GASTOS ASOCIADOS
            _buildSectionTitle(theme, 'Gastos de Viaje', Icons.account_balance_wallet_outlined),
            if (gastos.isEmpty)
              const Text('Sin gastos registrados.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
            else
              ...gastos.map((g) => _buildGastoItem(g, theme)).toList(),

            const SizedBox(height: 32),
            
            if (tieneRuta)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.location_on),
                  label: const Text('VER RECORRIDO COMPLETO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    side: BorderSide(color: theme.secondary, width: 1.5),
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

  Widget _buildInfoCard(FlutterFlowTheme theme, String choferNombre) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildDetailRow('Chofer', choferNombre, Icons.person),
          const Divider(),
          _buildDetailRow('Vehículo', _viaje!['vehiculo_codigo'] ?? 'S/D', Icons.local_shipping),
          const Divider(),
          _buildDetailRow('Estado', _viaje!['estado'] ?? 'Planificado', Icons.info_outline),
          const Divider(),
          _buildDetailRow('Fecha', _viaje!['fecha'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(_viaje!['fecha'])) : 'S/D', Icons.calendar_today),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFC68E17)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(FlutterFlowTheme theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: theme.primary),
          const SizedBox(width: 8),
          Text(title, style: theme.titleSmall),
        ],
      ),
    );
  }

  Widget _buildParadaItem(Map<String, dynamic> p, FlutterFlowTheme theme) {
    final items = List<Map<String, dynamic>>.from(p['parada_items'] ?? []);
    final remito = p['remito_id'] != null ? 'REMITO ASOCIADO: #${p['remito_id']}' : 'PENDIENTE DE REMITO';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: theme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('#${p['orden_secuencia']}', style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['ubicacion'] ?? 'Sin Nombre', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(p['localidad'] ?? 'S/D', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              Text(p['tipo_operacion']?.toUpperCase() ?? 'OP', style: TextStyle(color: theme.secondary, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
          const Divider(),
          if (items.isNotEmpty) ...[
            ...items.map((it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('${it['producto_codigo'] ?? 'S/N'}: ', style: const TextStyle(fontSize: 13)),
                  Text('${it['cantidad'] ?? 0} ${it['unidad'] ?? 'KG'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            )).toList(),
            const SizedBox(height: 8),
          ],
          // REMITO ASOCIADO
          Row(
            children: [
              Icon(Icons.description, size: 14, color: p['remito_id'] != null ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              Text(remito, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: p['remito_id'] != null ? Colors.green : Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGastoItem(Map<String, dynamic> g, FlutterFlowTheme theme) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black12)),
      child: ListTile(
        leading: const Icon(Icons.receipt_long, color: Color(0xFF1E352F)),
        title: Text(g['categoria'] ?? 'Gasto'),
        subtitle: Text(DateFormat('dd/MM').format(DateTime.parse(g['fecha']))),
        trailing: Text('\$${g['monto']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
      ),
    );
  }

  void _openMap(List<Map<String, dynamic>> paradas) async {
    if (paradas.isEmpty) return;
    final localities = paradas.map((p) => p['localidad']).where((l) => l != null).join('|');
    final url = 'https://www.google.com/maps/dir/?api=1&origin=General+Pico&destination=General+Pico&waypoints=$localities&travelmode=driving';
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }
}
