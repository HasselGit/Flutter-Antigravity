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

    final rutasRaw = List<Map<String, dynamic>>.from(_viaje!['rutas_data'] ?? []);

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
              // Aviso de ruta bloqueada (si aplica)
              if (esEnCurso)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.alt_route_rounded, size: 18),
                          label: const Text('SOLICITAR CAMBIO DE RECORRIDO'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orange),
                            foregroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _mostrarDialogoSolicitudCambio(paradas),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withOpacity(0.3))),
                        child: const Row(children: [
                          Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Puede solicitar cambios en nodos futuros sin detener su marcha.',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                                  color: Colors.orange, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
            ],

            // SECCIÓN: HOJA DE RUTA (POR RUTAS)
            if (rutasRaw.isNotEmpty) ...[
              _buildSectionTitle(theme, 'Rutas del Viaje', Icons.map_outlined),
              ...rutasRaw.map((ruta) => _buildRutaGroup(ruta, theme)).toList(),
            ] else ...[
              _buildSectionTitle(theme, 'Operaciones y Documentación', Icons.assignment_outlined),
              if (!tieneRuta)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('Pendiente de asignar ruta', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
                )
              else
                ...paradas.map((p) => _buildParadaItem(p, theme)).toList(),
            ],
            
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
    final fmt = DateFormat('dd/MM HH:mm');
    String _format(dynamic date) => date != null ? fmt.format(DateTime.parse(date)) : '—';

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
          // TIMELINE DATES
          _buildTimelineRow('Planificado', _format(_viaje!['fecha_planificada'] ?? _viaje!['fecha']), Icons.calendar_today, Colors.blue),
          _buildTimelineRow('Inicio Real', _format(_viaje!['fecha_inicio']), Icons.play_arrow_rounded, Colors.green),
          if (_viaje!['fecha_terminado'] != null)
            _buildTimelineRow('Terminado', _format(_viaje!['fecha_terminado']), Icons.check_circle_rounded, DesignTokens.primary),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
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

  Widget _buildRutaGroup(Map<String, dynamic> ruta, FlutterFlowTheme theme) {
    final paradasRuta = List<Map<String, dynamic>>.from(ruta['paradas'] ?? []);
    final bool cambioPendiente = ruta['cambio_solicitado'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: DesignTokens.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.route_rounded, size: 18, color: DesignTokens.primary),
              const SizedBox(width: 10),
              Text(
                'RUTA: ${ruta['ruta_codigo']}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: DesignTokens.primary),
              ),
              const Spacer(),
              if (cambioPendiente)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(6)),
                  child: const Text('CAMBIO SOLICITADO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        if (cambioPendiente && _canEditRoute)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: TextButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('APROBAR CAMBIO DE RECORRIDO'),
              onPressed: () => _aprobarCambio(ruta['id']),
              style: TextButton.styleFrom(foregroundColor: Colors.green, padding: EdgeInsets.zero),
            ),
          ),
        ...paradasRuta.map((p) => _buildParadaItem(p, theme)).toList(),
      ],
    );
  }

  void _mostrarDialogoSolicitudCambio(List<Map<String, dynamic>> paradas) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Solicitar Cambio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿A partir de qué nodo desea solicitar el cambio de recorrido?'),
            const SizedBox(height: 20),
            ...paradas.where((p) => AppStates.normalize(p['estado']) != AppStates.terminado).map((p) => ListTile(
              title: Text('${p['orden_secuencia']}. ${p['ubicacion']}'),
              onTap: () {
                Navigator.pop(ctx);
                _solicitarCambio(p);
              },
            )).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _solicitarCambio(Map<String, dynamic> parada) async {
    setState(() => _saving = true);
    try {
      final rutaId = parada['ruta_id'];
      if (rutaId == null) throw 'La parada no tiene una ruta vinculada';
      
      await SupabaseService().solicitarCambioRuta(rutaId: rutaId, paradaId: parada['id']);
      
      // WhatsApp notification
      final msg = 'SOLICITUD DE CAMBIO DE RUTA\nViaje: ${_viaje!['viaje_codigo']}\nChofer: $_userId\nA partir de: ${parada['ubicacion']}';
      final url = 'https://wa.me/5492302123456?text=${Uri.encodeComponent(msg)}'; // Replace with real group/role numbers
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _aprobarCambio(String rutaId) async {
    setState(() => _saving = true);
    try {
      await SupabaseService().aprobarCambioRuta(rutaId: rutaId, rolAprobador: _userRole ?? 'Gerente');
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambio aprobado'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _saving = false);
    }
  }

  void _openMap(List<Map<String, dynamic>> paradas) async {
    if (paradas.isEmpty) return;
    
    // Ordenar paradas por secuencia para asegurar el recorrido correcto
    final paradasOrdenadas = List<Map<String, dynamic>>.from(paradas);
    paradasOrdenadas.sort((a, b) => (a['orden_secuencia'] ?? 0).compareTo(b['orden_secuencia'] ?? 0));
    
    final waypoints = paradasOrdenadas
        .map((p) => '${p['ubicacion']}, ${p['localidad']}, La Pampa, Argentina')
        .map((s) => Uri.encodeComponent(s))
        .join('|');
        
    final url = 'https://www.google.com/maps/dir/?api=1&origin=General+Pico,+La+Pampa&destination=General+Pico,+La+Pampa&waypoints=$waypoints&travelmode=driving';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps'))
        );
      }
    }
  }
}
