import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase_service.dart';
import '../backend/app_states.dart';
import '../backend/design_tokens.dart';

class CargaDetalleWidget extends StatefulWidget {
  final String? cargaId;
  final bool isNew;
  const CargaDetalleWidget({super.key, this.cargaId, this.isNew = false});
  static String routePath = '/cargaDetalle';

  @override
  State<CargaDetalleWidget> createState() => _CargaDetalleWidgetState();
}

class _CargaDetalleWidgetState extends State<CargaDetalleWidget> {
  Map<String, dynamic>? _carga;
  bool _loading = true;
  bool _saving = false;
  String? _userRole;
  String? _userId;

  // Para nueva carga
  List<Map<String, dynamic>> _viajes = [];
  List<Map<String, dynamic>> _productos = [];
  Map<String, dynamic>? _selectedViaje;
  String? _selectedViajeId;
  final List<Map<String, dynamic>> _newItems = [];

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_puesto');
    _userId = prefs.getString('user_id');
    if (widget.isNew) {
      await _loadCatalogos();
      if (mounted) setState(() => _loading = false);
    } else {
      await _loadCarga();
    }
  }

  Future<void> _loadCatalogos() async {
    final service = SupabaseService();
    try {
      final viajesData = await service.getViajes();
      // Solo viajes en Pendiente
      _viajes = viajesData.where((v) => AppStates.normalize(v['estado']) == AppStates.pendiente).toList();
    } catch (e) {
      print('CargaDetalle: Error cargando viajes: $e');
    }

    try {
      _productos = await service.getProductos();
    } catch (e) {
      print('CargaDetalle: Error cargando productos: $e');
    }
  }

  Future<void> _loadCarga() async {
    if (widget.cargaId == null) return;
    setState(() => _loading = true);
    try {
      final data = await SupabaseService().getCargaDetalle(widget.cargaId!);
      if (mounted) setState(() { _carga = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isDeposito => _userRole == 'Encargado de Deposito' || _userRole == 'Deposito';
  bool get _canChangeEstado => _isDeposito;

  Future<void> _cambiarEstado(String nuevoEstado) async {
    if (widget.cargaId == null) return;
    setState(() => _saving = true);
    try {
      await SupabaseService().updateCargaEstado(widget.cargaId!, nuevoEstado);
      await _loadCarga();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Carga actualizada a: $nuevoEstado'),
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

  Future<void> _crearCarga() async {
    if (_selectedViaje == null || _newItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccione viaje y agregue al menos un ítem')));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService().createCarga(
        viajeId: _selectedViaje!['id'].toString(),
        items: _newItems,
        createdBy: _userId ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Carga creada correctamente'), backgroundColor: Colors.green));
        context.pop();
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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: DesignTokens.secondary)));
    if (widget.isNew) return _buildNewCarga();
    if (_carga == null) return Scaffold(appBar: AppBar(title: const Text('Carga no encontrada')));
    return _buildDetalle();
  }

  // ─── DETALLE DE CARGA EXISTENTE ───────────────────────────────────────────

  Widget _buildDetalle() {
    final estado = _carga!['estado'] ?? AppStates.pendiente;
    final viaje = _carga!['viaje'] as Map<String, dynamic>? ?? {};
    final chofer = _carga!['chofer'] as Map<String, dynamic>? ?? {};
    final vehiculo = _carga!['vehiculo'] as Map<String, dynamic>? ?? {};
    final items = List<Map<String, dynamic>>.from(_carga!['carga_items'] ?? []);
    final codigo = _carga!['carga_codigo'] ?? 'S/C';
    final viajeCode = viaje['viaje_codigo'] ?? 'S/V';
    final vehiculoCode = viaje['vehiculo_codigo'] ?? 'S/V';
    final choferNombre = chofer.isNotEmpty
        ? '${chofer['nombre'] ?? ''} ${chofer['apellido'] ?? ''}'.trim()
        : 'Sin chofer';

    final capKg = (vehiculo['capacidad_kg'] as num?)?.toDouble() ?? 0;
    final capTamb = (vehiculo['capacidad_tambores'] as num?)?.toInt() ?? 0;
    final cargaActualKg = (vehiculo['carga_actual_kg'] as num?)?.toDouble() ?? 0;
    final cargaActualTamb = (vehiculo['carga_actual_tambores'] as num?)?.toInt() ?? 0;

    // Calcular lo que va a agregar esta carga
    double estaCargaKg = 0;
    int estaCargaTamb = 0;
    for (final it in items) {
      final qty = (it['cantidad'] as num?)?.toDouble() ?? 0;
      final prod = (it['producto_codigo'] ?? '').toLowerCase();
      if (prod.contains('tcm') || prod.contains('tambor')) {
        estaCargaKg += qty * 300; estaCargaTamb += qty.round();
      } else if (prod.contains('tv') || prod.contains('vacio')) {
        estaCargaKg += qty * 20; estaCargaTamb += qty.round();
      } else { estaCargaKg += qty; }
    }

    final proyectadoKg = cargaActualKg + estaCargaKg;
    final excede = capKg > 0 && proyectadoKg > capKg;
    final progreso = capKg > 0 ? (proyectadoKg / capKg).clamp(0.0, 1.2) : 0.0;

    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(codigo,
            style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800,
                fontSize: 17, color: DesignTokens.primary)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── HEADER ────────────────────────────────────────────────────────
          _sectionHeader(codigo, estado, viajeCode, vehiculoCode, choferNombre),
          const SizedBox(height: 20),

          // ── DEPÓSITO CIRCULANTE ───────────────────────────────────────────
          if (vehiculo.isNotEmpty) ...[
            _labelText('DEPÓSITO CIRCULANTE DEL VEHÍCULO'),
            const SizedBox(height: 10),
            _depositoCard(capKg, capTamb, cargaActualKg, cargaActualTamb,
                estaCargaKg, estaCargaTamb, proyectadoKg, excede, progreso),
            const SizedBox(height: 20),
          ],

          // ── ÍTEMS DE CARGA ────────────────────────────────────────────────
          _labelText('ÍTEMS DE LA CARGA'),
          const SizedBox(height: 10),
          if (items.isEmpty)
            _emptyCard('No hay ítems en esta carga')
          else
            ...items.map((it) => _itemCard(it)).toList(),
          const SizedBox(height: 24),

          // ── BOTONES DE ACCIÓN (solo Depósito) ─────────────────────────────
          if (_canChangeEstado) ...[
            if (estado == AppStates.pendiente)
              _actionButton(
                label: 'INICIAR CARGA',
                icon: Icons.play_circle_outline_rounded,
                color: const Color(0xFF1565C0),
                onPressed: _saving ? null : () => _cambiarEstado(AppStates.enCurso),
              ),
            if (estado == AppStates.enCurso)
              _actionButton(
                label: 'CONFIRMAR CARGA TERMINADA',
                icon: Icons.check_circle_outline_rounded,
                color: excede ? Colors.orange : const Color(0xFF1A6B43),
                onPressed: _saving ? null : () => _confirmarTerminar(excede),
              ),
            if (estado == AppStates.terminado)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFFD4F0E1), borderRadius: BorderRadius.circular(14)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF1A6B43)),
                    SizedBox(width: 10),
                    Text('Carga completada — Depósito actualizado',
                        style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700,
                            color: Color(0xFF1A6B43))),
                  ],
                ),
              ),
            const SizedBox(height: 40),
          ],
        ]),
      ),
    );
  }

  Future<void> _confirmarTerminar(bool excede) async {
    if (excede) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ Capacidad excedida',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          content: const Text('Esta carga excede la capacidad del vehículo. ¿Confirmar de todas formas?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('CONFIRMAR', style: TextStyle(color: Colors.orange))),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _cambiarEstado(AppStates.terminado);
  }

  Widget _sectionHeader(String codigo, String estado, String viajeCode,
      String vehiculoCode, String choferNombre) {
    final bgColor = Color(AppStates.stateBgColor(estado));
    final textColor = Color(AppStates.stateTextColor(estado));
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(codigo, style: const TextStyle(fontFamily: 'Manrope',
              fontWeight: FontWeight.w900, fontSize: 20, color: DesignTokens.primary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
            child: Text(estado.toUpperCase(), style: TextStyle(fontFamily: 'Work Sans',
                fontWeight: FontWeight.w800, fontSize: 10, color: textColor)),
          ),
        ]),
        const SizedBox(height: 16),
        _detailRow(Icons.local_shipping_rounded, 'Viaje', viajeCode),
        _detailRow(Icons.directions_car_rounded, 'Vehículo', vehiculoCode),
        _detailRow(Icons.person_rounded, 'Chofer', choferNombre),
      ]),
    );
  }

  Widget _depositoCard(double capKg, int capTamb, double actualKg, int actualTamb,
      double estaCargaKg, int estaCargaTamb, double proyectadoKg, bool excede, double progreso) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: excede ? const Color(0xFFFFF3E0) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: excede ? Colors.orange.withOpacity(0.4) : DesignTokens.primary.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (excede) ...[
          Row(children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
            SizedBox(width: 6),
            Text('CAPACIDAD EXCEDIDA', style: TextStyle(fontFamily: 'Work Sans',
                fontWeight: FontWeight.w800, fontSize: 11, color: Colors.orange)),
          ]),
          const SizedBox(height: 10),
        ],
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${proyectadoKg.round()} kg',
                style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900,
                    fontSize: 22, color: excede ? Colors.orange : DesignTokens.primary)),
            Text('de ${capKg.round()} kg cap.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                    color: DesignTokens.onSurfaceVariant.withOpacity(0.6))),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${actualTamb + estaCargaTamb} tamb.',
                style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900,
                    fontSize: 20, color: DesignTokens.primary)),
            Text('de $capTamb cap.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                    color: DesignTokens.onSurfaceVariant.withOpacity(0.6))),
          ]),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progreso.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: DesignTokens.primary.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation<Color>(
                excede ? Colors.orange : const Color(0xFF1A6B43)),
          ),
        ),
        const SizedBox(height: 10),
        Text('Carga actual: ${actualKg.round()} kg  |  Esta carga: +${estaCargaKg.round()} kg',
            style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                color: DesignTokens.onSurfaceVariant.withOpacity(0.6))),
      ]),
    );
  }

  Widget _itemCard(Map<String, dynamic> it) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: DesignTokens.surface, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.inventory_2_rounded, size: 18, color: DesignTokens.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it['producto_codigo'] ?? 'Producto',
                style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800,
                    fontSize: 14, color: DesignTokens.primary)),
            Text(it['unidad'] ?? '', style: const TextStyle(fontSize: 11,
                color: DesignTokens.onSurfaceVariant)),
          ]),
        ),
        Text('${it['cantidad']}',
            style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900,
                fontSize: 18, color: DesignTokens.primary)),
      ]),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 15, color: DesignTokens.secondary),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontFamily: 'Work Sans',
            fontWeight: FontWeight.w700, fontSize: 13, color: DesignTokens.onSurfaceVariant)),
        Expanded(child: Text(value, style: const TextStyle(fontFamily: 'Inter',
            fontWeight: FontWeight.w600, fontSize: 13, color: DesignTokens.primary),
            overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _labelText(String text) => Text(text,
      style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800,
          fontSize: 11, color: DesignTokens.onSurfaceVariant, letterSpacing: 0.5));

  Widget _emptyCard(String msg) => Container(
    width: double.infinity, padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05))),
    child: Text(msg, textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Inter', color: DesignTokens.onSurfaceVariant)),
  );

  Widget _actionButton({required String label, required IconData icon,
      required Color color, VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: _saving
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(icon, color: Colors.white),
        label: Text(label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        style: ElevatedButton.styleFrom(
            backgroundColor: color, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0),
      ),
    );
  }

  // ─── NUEVA CARGA (formulario) ─────────────────────────────────────────────

  Widget _buildNewCarga() {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Nueva Carga',
            style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800,
                fontSize: 17, color: DesignTokens.primary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _labelText('1. SELECCIONAR VIAJE (estado Pendiente)'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DesignTokens.primary.withOpacity(0.1))),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Seleccionar viaje...', style: TextStyle(color: Colors.black38)),
                value: _selectedViajeId,
                items: _viajes.map((v) => DropdownMenuItem<String>(
                  value: v['id'].toString(),
                  child: Text('${v['viaje_codigo'] ?? 'S/C'} — ${v['vehiculo_codigo'] ?? 'S/V'}'),
                )).toList(),
                onChanged: (v) => setState(() {
                  _selectedViajeId = v;
                  _selectedViaje = _viajes.firstWhere((x) => x['id'].toString() == v);
                }),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _labelText('2. ÍTEMS DE CARGA'),
            TextButton.icon(
              onPressed: () => _showAddItemDialog(),
              icon: const Icon(Icons.add_rounded, size: 16, color: DesignTokens.primary),
              label: const Text('Agregar', style: TextStyle(color: DesignTokens.primary,
                  fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          if (_newItems.isEmpty)
            _emptyCard('Agregue ítems a la carga'),
          ..._newItems.asMap().entries.map((e) => Stack(
            children: [
              _itemCard(e.value),
              Positioned(top: 4, right: 4,
                child: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _newItems.removeAt(e.key)),
                )),
            ],
          )).toList(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _saving ? null : _crearCarga,
              style: DesignTokens.primaryButtonStyle,
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('CREAR CARGA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Future<void> _showAddItemDialog() async {
    Map<String, dynamic>? selectedProducto;
    String? selectedProductoCode;
    final qtyController = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Agregar Ítem', style: TextStyle(fontFamily: 'Manrope',
                    fontSize: 20, fontWeight: FontWeight.w800, color: DesignTokens.primary)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  hint: const Text('Producto'),
                  value: selectedProductoCode,
                  decoration: InputDecoration(
                      filled: true, fillColor: DesignTokens.surfaceLow,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none)),
                  items: _productos.map((p) => DropdownMenuItem<String>(
                    value: p['codigo'].toString(),
                    child: Text('${p['codigo'] ?? ''} — ${p['descripcion'] ?? ''}',
                        overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setModal(() {
                    selectedProductoCode = v;
                    selectedProducto = _productos.firstWhere((x) => x['codigo'].toString() == v);
                  }),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'Cantidad',
                      filled: true, fillColor: DesignTokens.surfaceLow,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (selectedProducto == null || qtyController.text.isEmpty) return;
                      setState(() {
                        _newItems.add({
                          'producto_codigo': selectedProducto!['codigo'] ?? selectedProducto!['descripcion'],
                          'cantidad': double.tryParse(qtyController.text) ?? 0,
                          'unidad': selectedProducto!['unidad'] ?? 'UN',
                        });
                      });
                      Navigator.pop(ctx);
                    },
                    style: DesignTokens.primaryButtonStyle,
                    child: const Text('AGREGAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
