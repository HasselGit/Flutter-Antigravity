import 'package:flutter/material.dart';
import 'package:geo_logistica/backend/supabase_service.dart';
import 'package:geo_logistica/backend/design_tokens.dart';
import 'package:geo_logistica/backend/app_states.dart';
import 'package:geo_logistica/flutter_flow/flutter_flow_theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViajeDetalleWidget extends StatefulWidget {
  final String viajeId;
  const ViajeDetalleWidget({super.key, required this.viajeId});

  @override
  State<ViajeDetalleWidget> createState() => _ViajeDetalleWidgetState();
}

class _ViajeDetalleWidgetState extends State<ViajeDetalleWidget> {
  Map<String, dynamic>? _viaje;
  bool _loading = true;
  bool _saving = false;
  String? _userRole;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadRoleAndData();
  }

  Future<void> _loadRoleAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_puesto');
    _userId = prefs.getString('user_id');
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService().getViajeDetalle(widget.viajeId);
      if (mounted) setState(() => _viaje = data);
    } catch (e) {
      print('Error cargando detalle: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isChofer => _userRole == 'Chofer';
  bool get _canEditRoute =>
      _userRole == 'Gerente' || _userRole == 'CEO' || _userRole == 'Compras';

  Future<void> _cambiarEstado(String nuevoEstado) async {
    setState(() => _saving = true);
    try {
      await SupabaseService().updateViajeEstado(widget.viajeId, nuevoEstado);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Viaje actualizado: $nuevoEstado'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
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

    final bool esPendiente = _viaje!['estado'] == AppStates.pendiente;
    final bool esEnCurso = _viaje!['estado'] == AppStates.enCurso;
    final bool tieneRuta = paradas.isNotEmpty;
    final bool todasTerminadas = tieneRuta &&
        paradas.every((p) => AppStates.normalize(p['estado']) == AppStates.terminado);

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

            // BOTÓN AGREGAR RUTA (solo Gerente/CEO/Compras, si Pendiente y sin ruta)
            if (_canEditRoute && esPendiente && !tieneRuta)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_road),
                    label: const Text('AGREGAR RUTA Y SOLICITUDES'),
                    style: DesignTokens.primaryButtonStyle,
                    onPressed: () => context.push('/planificarViaje?editId=${widget.viajeId}'),
                  ),
                ),
              ),

            // BOTONES DE ESTADO PARA CHOFER
            if (_isChofer) ...[
              if (esPendiente && tieneRuta)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton.icon(
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.play_circle_outline_rounded),
                      label: const Text('INICIAR VIAJE'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: _saving ? null : () => _cambiarEstado(AppStates.enCurso),
                    ),
                  ),
                ),
              if (esEnCurso && todasTerminadas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton.icon(
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('FINALIZAR VIAJE'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A6B43),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: _saving ? null : () => _cambiarEstado(AppStates.terminado),
                    ),
                  ),
                ),
              // Aviso de ruta bloqueada
              if (esEnCurso)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3))),
                    child: const Row(children: [
                      Icon(Icons.lock_outline_rounded, color: Colors.orange, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ruta bloqueada — Contacte al Gerente para modificaciones.',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                              color: Colors.orange, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ),
            ],

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
                  style: DesignTokens.secondaryButtonStyle,
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: theme.primary.withOpacity(0.05), shape: BoxShape.circle),
                child: Center(child: Text('${p['orden_secuencia']}', style: TextStyle(color: theme.primary, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['ubicacion'] ?? 'Sin Apicultor', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF08201A))),
                    Text(p['localidad'] ?? 'Sin Localidad', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: theme.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text((p['tipo'] ?? 'Operación').toUpperCase(), style: TextStyle(color: theme.primary, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 0.5),
          ),
          if (items.isNotEmpty) ...[
            ...items.map((it) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, size: 16, color: Color(0xFFC68E17)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(it['producto_codigo'] ?? 'Producto', style: const TextStyle(fontSize: 14, color: Color(0xFF1E352F), fontWeight: FontWeight.w500))),
                  Text('${it['cantidad'] ?? 0} ${it['unidad'] ?? 'KG'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF08201A))),
                ],
              ),
            )).toList(),
            const SizedBox(height: 8),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p['remito_id'] != null ? Colors.green.withOpacity(0.05) : Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.description_outlined, size: 16, color: p['remito_id'] != null ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Text(remito, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p['remito_id'] != null ? Colors.green : Colors.orange)),
              ],
            ),
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
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
