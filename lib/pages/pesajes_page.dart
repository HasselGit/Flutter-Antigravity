import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../backend/design_tokens.dart';
import 'agregar_pesaje.dart';

/// Lista de pesajes agrupados por parada/viaje
class PesajesPageWidget extends StatefulWidget {
  const PesajesPageWidget({super.key});

  @override
  State<PesajesPageWidget> createState() => _PesajesPageWidgetState();
}

class _PesajesPageWidgetState extends State<PesajesPageWidget> {
  bool _loading = true;
  List<Map<String, dynamic>> _grupos = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;

      // Obtener todos los pesajes con info de viaje
      final data = await client
          .from('pesajes')
          .select('*')
          .order('created_at', ascending: false);

      final pesajes = List<Map<String, dynamic>>.from(data);

      if (pesajes.isEmpty) {
        if (mounted) setState(() { _grupos = []; _loading = false; });
        return;
      }

      // Agrupar por parada_id
      final Map<String, List<Map<String, dynamic>>> porParada = {};
      for (var p in pesajes) {
        final paradaId = p['parada_id']?.toString() ?? 'sin_parada';
        porParada.putIfAbsent(paradaId, () => []).add(p);
      }

      // Obtener datos de paradas
      final paradaIds = porParada.keys.where((k) => k != 'sin_parada').toList();
      Map<String, Map<String, dynamic>> paradaMap = {};
      if (paradaIds.isNotEmpty) {
        final paradasRes = await client
            .from('paradas')
            .select('id, viaje_id, tipo, localidad, ubicacion')
            .in_('id', paradaIds);
        for (var p in paradasRes) {
          paradaMap[p['id'].toString()] = Map<String, dynamic>.from(p);
        }
      }

      // Obtener datos de viajes
      final viajeIds = paradaMap.values.map((p) => p['viaje_id']?.toString()).whereType<String>().toSet().toList();
      Map<String, Map<String, dynamic>> viajeMap = {};
      if (viajeIds.isNotEmpty) {
        final viajesRes = await client
            .from('viajes')
            .select('id, viaje_codigo, fecha')
            .in_('id', viajeIds);
        for (var v in viajesRes) {
          viajeMap[v['id'].toString()] = Map<String, dynamic>.from(v);
        }
      }

      // Construir grupos enriquecidos
      final grupos = porParada.entries.map((entry) {
        final paradaId = entry.key;
        final items = entry.value;
        final parada = paradaMap[paradaId] ?? {};
        final viajeId = parada['viaje_id']?.toString() ?? '';
        final viaje = viajeMap[viajeId] ?? {};

        final totalBruto = items.fold(0.0, (s, p) => s + (double.tryParse(p['peso_bruto']?.toString() ?? '0') ?? 0));
        final totalTara = items.fold(0.0, (s, p) => s + (double.tryParse(p['tara']?.toString() ?? '0') ?? 0));
        final totalNeto = items.fold(0.0, (s, p) => s + (double.tryParse(p['peso_neto']?.toString() ?? '0') ?? 0));

        return {
          'parada_id': paradaId,
          'viaje_id': viajeId,
          'viaje_codigo': viaje['viaje_codigo'] ?? 'V-S/N',
          'viaje_fecha': viaje['fecha'],
          'apicultor': parada['ubicacion'] ?? parada['localidad'] ?? (items[0]['apicultor_id'] ?? 'S/D'),
          'localidad': parada['localidad'] ?? 'S/D',
          'tipo': parada['tipo'] ?? 'Recolección',
          'items': items,
          'tcm_count': items.length,
          'total_bruto': totalBruto,
          'total_tara': totalTara,
          'total_neto': totalNeto,
          'fecha': items[0]['created_at'],
        };
      }).toList();

      // Ordenar por fecha descendente
      grupos.sort((a, b) {
        final fa = DateTime.tryParse(a['fecha']?.toString() ?? '') ?? DateTime(2000);
        final fb = DateTime.tryParse(b['fecha']?.toString() ?? '') ?? DateTime(2000);
        return fb.compareTo(fa);
      });

      if (mounted) {
        setState(() { _grupos = grupos; _loading = false; });
      }
    } catch (e) {
      debugPrint('PesajesPage: Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DesignTokens.primary, size: 20),
          onPressed: () => context.go('/home'),
        ),
        centerTitle: false,
        title: Text('Pesajes', style: DesignTokens.headlineStyle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: DesignTokens.primary),
            onPressed: _fetchData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: DesignTokens.secondary,
              child: _grupos.isEmpty ? _buildEmpty() : _buildList(),
            ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _grupos.length,
      itemBuilder: (context, index) => _buildCard(_grupos[index]),
    );
  }

  Widget _buildCard(Map<String, dynamic> g) {
    final items = g['items'] as List<Map<String, dynamic>>;
    final viajeCode = g['viaje_codigo'] as String;
    final apicultor = g['apicultor'] as String;
    final localidad = g['localidad'] as String;
    final tcmCount = g['tcm_count'] as int;
    final totalNeto = g['total_neto'] as double;
    final totalBruto = g['total_bruto'] as double;
    final fechaStr = g['viaje_fecha'] != null
        ? DateFormat('dd/MM/yy').format(DateTime.tryParse(g['viaje_fecha'].toString()) ?? DateTime.now())
        : '--/--/--';

    return GestureDetector(
      onTap: () => _showDetalle(g),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
          border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: DesignTokens.primary.withOpacity(0.03),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: DesignTokens.primary.withOpacity(0.06))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.scale_rounded, size: 18, color: DesignTokens.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(viajeCode, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 15, color: DesignTokens.primary)),
                        Text(fechaStr, style: TextStyle(fontSize: 11, color: DesignTokens.primary.withOpacity(0.4))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFFDF7E7), borderRadius: BorderRadius.circular(20)),
                    child: Text('$tcmCount TCM', style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFFC68E17))),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _infoChip(Icons.person_pin_circle_rounded, 'APICULTOR', apicultor)),
                      const SizedBox(width: 12),
                      Expanded(child: _infoChip(Icons.location_on_rounded, 'LOCALIDAD', localidad)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _miniStat('BRUTO', totalBruto > 0 ? '${totalBruto.toStringAsFixed(0)} kg' : '—'),
                      const SizedBox(width: 16),
                      _miniStat('NETO', totalNeto > 0 ? '${totalNeto.toStringAsFixed(0)} kg' : '—', highlight: true),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Text('VER DETALLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: DesignTokens.primary.withOpacity(0.6), fontFamily: 'Work Sans')),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 14, color: DesignTokens.primary.withOpacity(0.4)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: DesignTokens.primary.withOpacity(0.4)),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.black38)),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF424846)), overflow: TextOverflow.ellipsis),
            ],
          )),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black38)),
        Text(value, style: TextStyle(fontFamily: 'Manrope', fontSize: 14, fontWeight: FontWeight.w800, color: highlight ? DesignTokens.secondary : const Color(0xFF424846))),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.scale_outlined, size: 48, color: DesignTokens.secondary),
          ),
          const SizedBox(height: 24),
          Text('Sin registros de pesajes', style: DesignTokens.headlineStyle().copyWith(fontSize: 18, color: const Color(0xFF424846))),
          const SizedBox(height: 8),
          Text('Los pesajes aparecerán aquí cuando se registren\ndesde una parada de recolección activa.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black38)),
        ],
      ),
    );
  }

  // ─── MODAL DE DETALLE ─────────────────────────────────────────────────────────
  void _showDetalle(Map<String, dynamic> g) {
    final items = g['items'] as List<Map<String, dynamic>>;
    final apicultor = g['apicultor'] as String;
    final localidad = g['localidad'] as String;
    final viajeCode = g['viaje_codigo'] as String;
    final totalBruto = g['total_bruto'] as double;
    final totalTara = g['total_tara'] as double;
    final totalNeto = g['total_neto'] as double;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, sc) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFBFBFB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.only(top: 12), width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.12), borderRadius: BorderRadius.circular(2))),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(viajeCode, style: DesignTokens.headlineStyle().copyWith(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('$apicultor  •  $localidad', style: const TextStyle(fontSize: 13, color: Colors.black45)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFFDF7E7), borderRadius: BorderRadius.circular(20)),
                      child: Text('${items.length} TCM', style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFC68E17))),
                    ),
                  ],
                ),
              ),
              // Totales
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(children: [
                  _totalBox('BRUTO TOTAL', totalBruto, false),
                  const SizedBox(width: 10),
                  _totalBox('TARA TOTAL', totalTara, false),
                  const SizedBox(width: 10),
                  _totalBox('NETO TOTAL', totalNeto, true),
                ]),
              ),
              // Tabla
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(color: Color(0xFF1E302C), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                        child: Row(children: [
                          _th('#', 1), _th('CÓD. SENASA', 4), _th('BRUTO', 2, right: true), _th('TARA', 2, right: true), _th('NETO', 2, right: true),
                        ]),
                      ),
                      Expanded(
                        child: items.isEmpty
                            ? const Center(child: Text('Sin registros', style: TextStyle(color: Colors.black38)))
                            : ListView.builder(
                                controller: sc,
                                itemCount: items.length,
                                itemBuilder: (ctx, i) => _detalleRow(i + 1, items[i]),
                              ),
                      ),
                      // Footer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: DesignTokens.primary.withOpacity(0.04),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                          border: const Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                        ),
                        child: Row(children: [
                          const Expanded(flex: 5, child: Text('TOTALES', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF1E302C)))),
                          Expanded(flex: 2, child: Text('${totalBruto.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846)))),
                          Expanded(flex: 2, child: Text('${totalTara.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846)))),
                          Expanded(flex: 2, child: Text('${totalNeto.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 14, color: DesignTokens.secondary))),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalBox(String label, double value, bool highlight) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? DesignTokens.secondary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlight ? DesignTokens.secondary.withOpacity(0.2) : const Color(0xFFEEEEEE)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: highlight ? DesignTokens.secondary : Colors.black38, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text('${value.toStringAsFixed(0)} kg', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 16, color: highlight ? DesignTokens.secondary : const Color(0xFF424846))),
        ]),
      ),
    );
  }

  Widget _th(String text, int flex, {bool right = false}) {
    return Expanded(flex: flex, child: Text(text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontFamily: 'Work Sans', color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5)));
  }

  Widget _detalleRow(int index, Map<String, dynamic> item) {
    final bruto = double.tryParse(item['peso_bruto']?.toString() ?? '0') ?? 0;
    final tara = double.tryParse(item['tara']?.toString() ?? '0') ?? 0;
    final neto = double.tryParse(item['peso_neto']?.toString() ?? '0') ?? 0;
    final isEven = index % 2 == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFFAFAFA) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Row(children: [
        Expanded(flex: 1, child: Text('$index', style: const TextStyle(fontSize: 11, color: Colors.black38))),
        Expanded(flex: 4, child: Text(item['senasa_codigo']?.toString() ?? 'TCM', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF424846)), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Text('${bruto.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF424846)))),
        Expanded(flex: 2, child: Text('${tara.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF424846)))),
        Expanded(flex: 2, child: Text('${neto.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w800, color: DesignTokens.secondary))),
      ]),
    );
  }
}
