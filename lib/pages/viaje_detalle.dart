import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geo_logistica/backend/supabase_service.dart';
import 'package:geo_logistica/backend/design_tokens.dart';
import 'package:geo_logistica/backend/app_states.dart';
import 'package:geo_logistica/flutter_flow/flutter_flow_theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

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
  bool get _isAdmin => Supabase.instance.client.auth.currentUser?.email == 'hassel00@gmail.com';
  bool get _canEditRoute =>
      _isAdmin || _userRole == 'Gerente' || _userRole == 'CEO' || _userRole == 'Compras';

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

    final paradas = List<Map<String, dynamic>>.from(_viaje!['paradas'] ?? [])
      ..sort((a, b) {
        final int oA = (a['orden_secuencia'] as num?)?.toInt() ?? 0;
        final int oB = (b['orden_secuencia'] as num?)?.toInt() ?? 0;
        return oA.compareTo(oB);
      });
    final gastos = List<Map<String, dynamic>>.from(_viaje!['gastos'] ?? []);
    final chofer = _viaje!['chofer'] ?? _viaje!['profiles'] ?? {};
    final choferNombre = (chofer['nombre'] != null) 
        ? '${chofer['nombre']} ${chofer['apellido']}' 
        : 'ID: ${_viaje!['chofer_id'] ?? 'S/D'}';

    final bool esPendiente = AppStates.normalize(_viaje!['estado']) == AppStates.pendiente;
    final bool esEnCurso = AppStates.normalize(_viaje!['estado']) == AppStates.enCurso;
    final bool tieneRuta = paradas.isNotEmpty;
    final bool todasTerminadas = tieneRuta &&
        paradas.every((p) => AppStates.normalize(p['estado']) == AppStates.terminado);

    final cargas = List<Map<String, dynamic>>.from(_viaje!['cargas'] ?? []);
    final bool tieneCargaPendiente = cargas.any((c) => AppStates.normalize(c['estado']) == AppStates.pendiente);
    final bool puedeIniciar = esPendiente && tieneRuta && !tieneCargaPendiente;

    final rutasRaw = List<Map<String, dynamic>>.from(_viaje!['rutas_data'] ?? []);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        title: Text('Detalle de Viaje: ${_viaje!['viaje_codigo']}', style: theme.headlineSmall),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.primary),
        actions: [
          // Botón de eliminar viaje: solo disponible para el admin
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: 'Eliminar viaje (Admin)',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar Viaje'),
                    content: Text('¿Está seguro de eliminar el viaje ${_viaje!['viaje_codigo']}? Esta acción no se puede deshacer.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('ELIMINAR'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  try {
                    await SupabaseService().deleteViaje(widget.viajeId);
                    if (mounted) context.pop();
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
        ],
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
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity, height: 56,
                        child: ElevatedButton.icon(
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.play_circle_outline_rounded),
                          label: const Text('INICIAR VIAJE'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: puedeIniciar ? const Color(0xFF1565C0) : Colors.grey,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: (_saving || !puedeIniciar) ? null : () => _cambiarEstado(AppStates.enCurso),
                        ),
                      ),
                      if (tieneCargaPendiente)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                              const SizedBox(width: 6),
                              Text('Carga pendiente de confirmación en depósito',
                                  style: TextStyle(fontSize: 10, color: Colors.orange[800], fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
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
            
            // SECCIÓN: CARGAS ASOCIADAS
            _buildSectionTitle(theme, 'Cargas del Vehículo', Icons.inventory_2_outlined),
            if (cargas.isEmpty)
              const Text('Sin cargas asignadas a este viaje.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
            else
              ...cargas.map((c) => _buildCargaItem(c, theme)).toList(),

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
    final remitos = List<Map<String, dynamic>>.from(p['remitos'] ?? []);
    final bool isViajeTerminado = AppStates.normalize(_viaje?['estado']) == AppStates.terminado;
    
    // Determinar tipo display dinámico basado en productos reales
    bool hasRecoleccion = false;
    bool hasDistribucion = false;
    for (var item in items) {
      final code = (item['producto_codigo'] ?? '').toString().toUpperCase();
      if (code == 'TCM' || code == '1' || code.contains('MIEL')) {
        hasRecoleccion = true;
      } else {
        hasDistribucion = true;
      }
    }
    
    String tipoDisplay = p['tipo'] ?? 'Operación';
    if (hasRecoleccion && hasDistribucion) {
      tipoDisplay = 'Mixta';
    } else if (hasRecoleccion) {
                          tipoDisplay = 'Recolección';
    } else if (hasDistribucion) {
      tipoDisplay = 'Distribución';
    }
    
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: (isViajeTerminado && !_isAdmin) ? null : () => context.push('/paradaDetalle?paradaId=${p['id']}').then((_) => _loadData()),

      child: Container(
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
                  child: Text(tipoDisplay.toUpperCase(), style: TextStyle(color: theme.primary, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                ),
                if (!isViajeTerminado) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: DesignTokens.primary, size: 20),
                ],
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 0.5),
            ),
            if (remitos.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'DOCUMENTOS DE CONFORMIDAD:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F5132),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              ...remitos.map((r) {
                final String pdfUrl = r['pdf_url'] ?? '';
                final String persona = r['persona_nombre'] ?? 'Receptor';
                final String fechaRemito = r['fecha'] != null 
                    ? DateFormat('dd/MM HH:mm').format(DateTime.parse(r['fecha'].toString()))
                    : '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remito - $persona',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF14532D)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (fechaRemito.isNotEmpty)
                              Text(
                                'Emitido: $fechaRemito',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                      if (pdfUrl.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.visibility_rounded, color: Color(0xFF16A34A), size: 18),
                          tooltip: 'Ver PDF',
                          onPressed: () => _showPdfPreviewDialog(context, pdfUrl, 'Remito - $persona'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_rounded, color: Color(0xFF16A34A), size: 18),
                          tooltip: 'Compartir',
                          onPressed: () => _sharePdf(pdfUrl, 'Remito - $persona'),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: p['remito_id'] != null ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 16, color: p['remito_id'] != null ? Colors.green[700] : Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      p['remito_id'] != null ? 'REMITO: EMITIDO' : 'REMITO: PENDIENTE', 
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.w900, 
                        color: p['remito_id'] != null ? Colors.green[700] : Colors.orange,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (p['remito_id'] != null) ...[
                      const Spacer(),
                      const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                    ],
                  ],
                ),
              ),
            ],
            if (p['remito_id'] == null && !isViajeTerminado && _isChofer)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_outlined, size: 14, color: theme.primary.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text(
                      'TOCA PARA GESTIONAR ESTA PARADA',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.primary.withOpacity(0.5), letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
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

  Widget _buildCargaItem(Map<String, dynamic> c, FlutterFlowTheme theme) {
    final estado = AppStates.normalize(c['estado']);
    final items = List<Map<String, dynamic>>.from(c['carga_items'] ?? []);
    final isTerminada = estado == AppStates.terminado;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isTerminada ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(Icons.inventory_2_outlined, color: isTerminada ? Colors.green : Colors.orange),
        title: Text(c['carga_codigo'] ?? 'CARGA', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Items: ${items.length} • Estado: $estado', style: const TextStyle(fontSize: 12)),
        trailing: isTerminada 
            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
            : const Icon(Icons.pending_actions_rounded, color: Colors.orange, size: 20),
        onTap: () => context.push('/cargaDetalle?id=${c['id']}'),
      ),
    );
  }

  Widget _buildRutaGroup(Map<String, dynamic> ruta, FlutterFlowTheme theme) {
    final paradasRuta = List<Map<String, dynamic>>.from(ruta['paradas'] ?? []);
    final bool isViajeEnCurso = AppStates.normalize(_viaje?['estado']) == AppStates.enCurso;
    final bool cambioPendiente = ruta['cambio_solicitado'] == true && isViajeEnCurso;

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
            ...paradas.where((p) => AppStates.normalize(p['estado']) != AppStates.normalize(AppStates.terminado)).map((p) => ListTile(
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
        .map((p) {
          final ubi = (p['ubicacion'] ?? '').toString();
          final loc = (p['localidad'] ?? '').toString();
          if (ubi.toLowerCase().contains('sin apicultor') || ubi.isEmpty) {
            if (loc.toLowerCase().contains('sin localidad') || loc.isEmpty) {
              return '';
            }
            return '$loc, La Pampa, Argentina';
          }
          if (loc.toLowerCase().contains('sin localidad') || loc.isEmpty) {
            return '$ubi, La Pampa, Argentina';
          }
          return '$ubi, $loc, La Pampa, Argentina';
        })
        .where((s) => s.isNotEmpty)
        .map((s) => Uri.encodeComponent(s))
        .join('|');
        
    final url = 'https://www.google.com/maps/dir/?api=1&origin=General+Pico,+La+Pampa&destination=General+Pico,+La+Pampa&waypoints=$waypoints&travelmode=driving';
    
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (err2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir Google Maps: $err2'))
          );
        }
      }
    }
  }

  Future<Uint8List> _downloadPdf(String url) async {
    try {
      // 1. Try public fetch
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return res.bodyBytes;
      }
    } catch (_) {}
    
    // 2. Fallback to Supabase Storage direct download
    try {
      final fileName = url.split('/').last;
      final bytes = await Supabase.instance.client.storage.from('remitos').download(fileName);
      return bytes;
    } catch (e) {
      print('Error downloading PDF from Storage: $e');
      rethrow;
    }
  }

  void _showPdfPreviewDialog(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Scaffold(
        appBar: AppBar(
          backgroundColor: DesignTokens.primary,
          elevation: 0,
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(ctx),
          ),
        ),
        body: FutureBuilder<Uint8List>(
          future: _downloadPdf(url),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: DesignTokens.secondary));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error al cargar PDF: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
              ));
            }
            return PdfPreview(
              build: (format) => snapshot.data!,
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              dynamicLayout: false,
            );
          },
        ),
      ),
    );
  }

  Future<void> _sharePdf(String url, String filename) async {
    try {
      final bytes = await _downloadPdf(url);
      await Printing.sharePdf(bytes: bytes, filename: '$filename.pdf');
    } catch (e) {
      print('Error sharing PDF: $e');
    }
  }
}
