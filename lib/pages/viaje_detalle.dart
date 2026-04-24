import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ViajeDetalleWidget extends StatefulWidget {
  final String? viajeId;
  const ViajeDetalleWidget({super.key, this.viajeId});

  static String routeName = 'ViajeDetalle';
  static String routePath = '/viajedetalle';

  @override
  State<ViajeDetalleWidget> createState() => _ViajeDetalleWidgetState();
}

class _ViajeDetalleWidgetState extends State<ViajeDetalleWidget> {
  Map<String, dynamic>? _viaje;
  List<Map<String, dynamic>> _paradas = [];
  bool _loading = true;
  String? _error;
  String? _userRole;

  // Stitch colors
  static const kPrimary = Color(0xFF08201A);
  static const kPrimaryContainer = Color(0xFF1E352F);
  static const kSecContainer = Color(0xFFFDBE49);
  static const kSurface = Color(0xFFFBF9F8);
  static const kSurfaceLow = Color(0xFFF5F3F3);
  static const kOnSurface = Color(0xFF1B1C1C);
  static const kOnSurfaceVariant = Color(0xFF424846);
  static const kOutlineVariant = Color(0xFFC2C8C4);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Fetch user role for permission checks
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          final profile = await Supabase.instance.client
              .from('profiles').select('puesto')
              .eq('user_id', user.id).maybeSingle();
          _userRole = profile?['puesto']?.toString();
        } catch (_) {}
      }

      if (widget.viajeId != null && widget.viajeId!.isNotEmpty) {
        final v = await Supabase.instance.client
            .from('viajes').select('*')
            .eq('id', widget.viajeId!).maybeSingle();
        _viaje = v;

        final p = await Supabase.instance.client
            .from('paradas').select('*, parada_items(*)')
            .eq('viaje_id', widget.viajeId!)
            .order('orden', ascending: true);
        _paradas = List<Map<String, dynamic>>.from(p);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _cambiarEstado(String nuevoEstado) async {
    if (widget.viajeId == null || widget.viajeId!.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('viajes').update({'estado': nuevoEstado})
          .eq('id', widget.viajeId!);
      await _fetchData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _openMaps(String localidad) async {
    final query = Uri.encodeComponent(localidad);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // Compute total kg from parada data — NO double counting
  double _calcCargaKg() {
    double total = 0;
    for (final p in _paradas) {
      // If the parada has a real pesaje (bruto_kg), use ONLY that
      if (p['bruto_kg'] != null) {
        total += (p['bruto_kg'] as num).toDouble();
      } else {
        // No pesaje yet — estimate from item quantities as fallback
        final items = p['parada_items'] as List? ?? [];
        for (final item in items) {
          final kg = double.tryParse(item['peso_kg']?.toString() ?? '') ?? 0;
          final qty = (item['cantidad'] as num?)?.toDouble() ?? 1;
          if (kg > 0) total += kg * qty;
        }
      }
    }
    return total;
  }

  // Check if user role can start/finish trips (only Chofer can)
  bool _canOperate() {
    return _userRole == 'Chofer';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: kSurface,
        appBar: _buildAppBar(null),
        body: const Center(child: CircularProgressIndicator(color: kSecContainer)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: kSurface,
        appBar: _buildAppBar(null),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Error al cargar datos', style: TextStyle(fontFamily: 'Manrope', fontSize: 16, color: kPrimary)),
          TextButton(onPressed: _fetchData, child: const Text('Reintentar')),
        ])),
      );
    }

    final estado = _viaje?['estado'] ?? 'Planificado';
    final vehiculo = _viaje?['vehiculo'] ?? 'Sin vehículo asignado';
    final distanciaKm = _viaje?['distancia_km'] ?? 0;
    final capacidadMax = double.tryParse(_viaje?['capacidad_kg']?.toString() ?? '') ?? 12000.0;
    final cargaActual = _calcCargaKg().clamp(0, capacidadMax).toDouble();
    final pct = capacidadMax > 0 ? (cargaActual / capacidadMax * 100).round() : 0;
    final progress = capacidadMax > 0 ? (cargaActual / capacidadMax).clamp(0.0, 1.0) : 0.0;

    final nextParada = _paradas.isNotEmpty ? _paradas.first : null;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: _buildAppBar(estado),
      body: RefreshIndicator(
        color: kSecContainer,
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            // ── Vehicle + Capacity card ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('VEHÍCULO ASIGNADO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 10, color: kOnSurfaceVariant, letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text(vehiculo.toString(), style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 20, color: kPrimary)),
                if (distanciaKm != 0) ...[
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('DISTANCIA TOTAL', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 9, color: kOnSurfaceVariant, letterSpacing: 0.8)),
                      Text('$distanciaKm KM', style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: kPrimary)),
                    ]),
                  ]),
                ],
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Capacidad de Carga', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500, color: kOnSurface)),
                  Text('$pct% OCUPADO', style: const TextStyle(fontFamily: 'Manrope', fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF7D5700))),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFEFEDED),
                    valueColor: const AlwaysStoppedAnimation<Color>(kSecContainer),
                  ),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${cargaActual.round()} KG', style: const TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
                  Text('MAX ${capacidadMax.round()} KG', style: const TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w700, color: kOnSurfaceVariant)),
                ]),
              ]),
            ),

            const SizedBox(height: 12),

            // ── Next Waypoint + Action ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                // Next Waypoint card (dark green — Stitch primary-container)
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: kPrimaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('NEXT WAYPOINT', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 10, color: kSecContainer, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      Text(
                        nextParada != null
                            ? (nextParada['nombre_cliente'] ?? nextParada['apicultor'] ?? 'Próxima parada')
                            : 'Sin paradas',
                        style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      if (nextParada?['localidad'] != null) ...[
                        const SizedBox(height: 4),
                        Text(nextParada!['localidad'].toString(), style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white.withOpacity(0.7))),
                      ],
                      const SizedBox(height: 14),
                      // Google Maps button
                      if (nextParada?['localidad'] != null)
                        GestureDetector(
                          onTap: () => _openMaps(nextParada!['localidad'].toString()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: kSecContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.navigation_rounded, size: 14, color: kPrimary),
                              SizedBox(width: 6),
                              Text('NAVEGAR', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 10, color: kPrimary)),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 12),

            // ── Start/End Route button — ONLY for Chofer role ──
            if (estado != 'Terminado' && _canOperate())
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _cambiarEstado(estado == 'Planificado' ? 'En Curso' : 'Terminado'),
                    icon: Icon(estado == 'Planificado' ? Icons.play_arrow_rounded : Icons.check_circle_rounded, color: kPrimary, size: 22),
                    label: Text(
                      estado == 'Planificado' ? 'INICIAR RUTA' : 'FINALIZAR RUTA',
                      style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 14, color: kPrimary, letterSpacing: 1),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSecContainer,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              )
            else if (estado != 'Terminado')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: kSurfaceLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kOutlineVariant),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.visibility_rounded, size: 16, color: kOnSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        'MODO ${_userRole?.toUpperCase() ?? "LECTURA"} — SOLO VISUALIZACIÓN',
                        style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 11, color: kOnSurfaceVariant, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ── Route Sheet Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Hoja de Ruta y Pesajes', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: kPrimary)),
                Row(children: [
                  const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF7D5700)),
                  const SizedBox(width: 4),
                  const Text('Filtrar', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF7D5700))),
                ]),
              ]),
            ),

            // ── Paradas ──
            if (_paradas.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.map_rounded, size: 48, color: kOnSurfaceVariant.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  const Text('Sin paradas registradas', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: kOnSurfaceVariant)),
                ]),
              )
            else
              ..._paradas.asMap().entries.map((e) => _buildStopCard(e.value, e.key + 1, _paradas.length)),

            const SizedBox(height: 100),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: kSecContainer,
        foregroundColor: kPrimary,
        child: const Icon(Icons.add_box_rounded, size: 28),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  AppBar _buildAppBar(String? estado) {
    Color chipColor = const Color(0xFF1565C0);
    Color chipBg = const Color(0xFFD6E4FF);
    if (estado == 'En Curso') { chipColor = const Color(0xFF7D5700); chipBg = const Color(0xFFFDEFCC); }
    else if (estado == 'Terminado') { chipColor = const Color(0xFF1A6B43); chipBg = const Color(0xFFD4F0E1); }

    return AppBar(
      backgroundColor: kSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: kPrimary),
        onPressed: () => context.pop(),
      ),
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('Control de Ruta', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 17, color: kPrimary)),
        if (estado != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(20)),
            child: Text(estado.toUpperCase(), style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 10, color: chipColor)),
          ),
        ],
      ]),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: kPrimary.withOpacity(0.08)),
      ),
    );
  }

  Widget _buildStopCard(Map<String, dynamic> stop, int idx, int total) {
    final nombre = stop['nombre_cliente'] ?? stop['apicultor'] ?? 'Parada $idx';
    final localidad = stop['localidad']?.toString() ?? '';
    final tipo = stop['tipo']?.toString() ?? 'Recolección';
    final items = stop['parada_items'] as List? ?? [];
    final hasPesaje = stop['bruto_kg'] != null;
    final isRecoleccion = tipo.toLowerCase().contains('recolec');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimary.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: kPrimary.withOpacity(0.06), shape: BoxShape.circle),
              child: const Icon(Icons.location_on_rounded, color: kPrimaryContainer, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre.toString(), style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 15, color: kPrimary)),
              if (localidad.isNotEmpty)
                Text('$localidad • Apiario #0$idx', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: kOnSurfaceVariant)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: kSurfaceLow, borderRadius: BorderRadius.circular(12)),
                child: Text('PARADA $idx/$total', style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 9, color: kOnSurfaceVariant)),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRecoleccion ? const Color(0xFFD4F0E1) : const Color(0xFFD6E4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(tipo.toUpperCase(), style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 8, color: isRecoleccion ? const Color(0xFF1A6B43) : const Color(0xFF1565C0))),
              ),
            ]),
          ]),
        ),

        // Pesaje section
        if (hasPesaje) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kPrimary.withOpacity(0.06))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('REGISTRO DE PESO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 10, color: kOnSurfaceVariant, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Peso Bruto', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: kOnSurfaceVariant)),
                  Text('${stop['bruto_kg']} KG', style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: kPrimary)),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Peso Neto', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: kOnSurfaceVariant)),
                  Text('${stop['neto_kg']} KG', style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF7D5700))),
                ])),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // Items — distinguish Recolección (KG) vs Distribución (u)
        if (items.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              isRecoleccion ? 'DETALLE DE CARGA (PESAJE)' : 'DETALLE DE ENTREGA',
              style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 10, color: kOnSurfaceVariant, letterSpacing: 0.8),
            ),
          ),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: kSurfaceLow, borderRadius: BorderRadius.circular(10), border: Border.all(color: kPrimary.withOpacity(0.05))),
              child: Row(children: [
                Icon(
                  isRecoleccion ? Icons.scale_rounded : Icons.inventory_2_rounded,
                  size: 16, color: kPrimaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  (item['producto'] ?? item['nombre'] ?? item['producto_codigo'] ?? 'Item').toString(),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: kOnSurface),
                )),
                Text(
                  isRecoleccion
                      ? '${item['peso_kg'] ?? item['cantidad'] ?? 0} KG'
                      : '${item['cantidad'] ?? item['cantidad_planificada'] ?? 0} U',
                  style: TextStyle(
                    fontFamily: 'Work Sans',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isRecoleccion ? const Color(0xFF7D5700) : kPrimaryContainer,
                  ),
                ),
              ]),
            ),
          )),
          const SizedBox(height: 8),
        ],

        // Map + Remito row
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            if (localidad.isNotEmpty)
              Expanded(child: GestureDetector(
                onTap: () => _openMaps(localidad),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: kPrimaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.map_rounded, size: 14, color: kSecContainer),
                    SizedBox(width: 6),
                    Text('VER EN MAPA', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 10, color: kSecContainer)),
                  ]),
                ),
              )),
            if (localidad.isNotEmpty) const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () {
                // Navigate to ParadaDetalle
                if (stop['id'] != null) {
                  context.push('/paradaDetalle?paradaId=${stop['id']}');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kOutlineVariant),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.visibility_rounded, size: 14, color: kPrimary),
                  SizedBox(width: 6),
                  Text('VER DETALLE', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 10, color: kPrimary)),
                ]),
              ),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kPrimary.withOpacity(0.07))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _navItem(Icons.home_rounded, 'HOME', false, () => context.go('/home')),
          _navItem(Icons.alt_route_rounded, 'RUTAS', true, () {}),
          _navItem(Icons.group_rounded, 'APICULTORES', false, () {}),
          _navItem(Icons.more_horiz_rounded, 'MÁS', false, () {}),
        ]),
      )),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active ? kPrimaryContainer.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: active ? kPrimaryContainer : kOnSurface.withOpacity(0.35)),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontFamily: 'Work Sans', fontWeight: active ? FontWeight.w800 : FontWeight.w500, fontSize: 9, color: active ? kPrimaryContainer : kOnSurface.withOpacity(0.35))),
      ]),
    );
  }
}

const kOutlineVariant = Color(0xFFC2C8C4);
