import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/design_tokens.dart';

/// Pantalla de Agregar Pesaje — asociada a una parada de recolección
/// Recibe: paradaId, viajeId, viajeCode, apicultorNombre, localidad
class AgregarPesajeWidget extends StatefulWidget {
  final String paradaId;
  final String? viajeId;
  final String viajeCode;
  final String apicultorNombre;
  final String localidad;
  final String? apicultorId;

  const AgregarPesajeWidget({
    super.key,
    required this.paradaId,
    this.viajeId,
    required this.viajeCode,
    required this.apicultorNombre,
    required this.localidad,
    this.apicultorId,
  });

  @override
  State<AgregarPesajeWidget> createState() => _AgregarPesajeWidgetState();
}

class _AgregarPesajeWidgetState extends State<AgregarPesajeWidget> {
  final List<Map<String, dynamic>> _tambores = [];
  bool _saving = false;
  bool _loadingExisting = true;

  // Controladores del formulario de nuevo tambor
  final _senasaController = TextEditingController();
  final _brutoController = TextEditingController();
  final _taraController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  double get _netoActual {
    final b = double.tryParse(_brutoController.text) ?? 0;
    final t = double.tryParse(_taraController.text) ?? 0;
    return (b - t).clamp(0, double.infinity);
  }

  double get _totalBruto => _tambores.fold(0, (s, t) => s + (t['peso_bruto'] as double));
  double get _totalTara => _tambores.fold(0, (s, t) => s + (t['tara'] as double));
  double get _totalNeto => _tambores.fold(0, (s, t) => s + (t['peso_neto'] as double));

  @override
  void initState() {
    super.initState();
    _loadExistingPesajes();
  }

  @override
  void dispose() {
    _senasaController.dispose();
    _brutoController.dispose();
    _taraController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPesajes() async {
    try {
      final data = await Supabase.instance.client
          .from('pesajes')
          .select('*')
          .eq('parada_id', widget.paradaId)
          .order('created_at');

      if (mounted) {
        setState(() {
          _tambores.addAll(List<Map<String, dynamic>>.from(data).map((r) => {
            'id': r['id'],
            'senasa_codigo': r['senasa_codigo'] ?? '',
            'peso_bruto': double.tryParse(r['peso_bruto']?.toString() ?? '0') ?? 0,
            'tara': double.tryParse(r['tara']?.toString() ?? '0') ?? 0,
            'peso_neto': double.tryParse(r['peso_neto']?.toString() ?? '0') ?? 0,
            'guardado': true,
          }));
          _loadingExisting = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  void _agregarTambor() {
    if (!_formKey.currentState!.validate()) return;

    final bruto = double.tryParse(_brutoController.text) ?? 0;
    final tara = double.tryParse(_taraController.text) ?? 0;
    final neto = (bruto - tara).clamp(0, double.infinity).toDouble();

    setState(() {
      _tambores.add({
        'senasa_codigo': _senasaController.text.trim(),
        'peso_bruto': bruto,
        'tara': tara,
        'peso_neto': neto,
        'guardado': false,
      });
    });

    _senasaController.clear();
    _brutoController.clear();
    _taraController.clear();
    FocusScope.of(context).unfocus();
  }

  void _eliminarTambor(int index) {
    setState(() => _tambores.removeAt(index));
  }

  Future<void> _guardarPesaje() async {
    if (_tambores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregá al menos un tambor antes de guardar')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final client = Supabase.instance.client;

      // Insertar solo los tambores no guardados aún
      final nuevos = _tambores.where((t) => t['guardado'] == false).toList();

      for (final t in nuevos) {
        await client.from('pesajes').insert({
          'parada_id': widget.paradaId,
          if (widget.viajeId != null) 'viaje_id': widget.viajeId,
          if (widget.apicultorId != null) 'apicultor_id': widget.apicultorId,
          'senasa_codigo': t['senasa_codigo'],
          'peso_bruto': t['peso_bruto'],
          'tara': t['tara'],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${_tambores.length} tambores guardados — Neto total: ${_totalNeto.toStringAsFixed(0)} kg'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DesignTokens.primary, size: 20),
          onPressed: () => context.pop(),
        ),
        centerTitle: false,
        title: Text('Agregar Pesaje', style: DesignTokens.headlineStyle()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08)),
        ),
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildContextCard()),
                SliverToBoxAdapter(child: _buildFormCard()),
                SliverToBoxAdapter(child: _buildTamboresHeader()),
                if (_tambores.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyTambores())
                else
                  SliverToBoxAdapter(child: _buildTabla()),
                if (_tambores.isNotEmpty)
                  SliverToBoxAdapter(child: _buildTotalesCard()),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _tambores.isNotEmpty ? _buildGuardarBtn() : null,
    );
  }

  Widget _buildContextCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: DesignTokens.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping_rounded, size: 20, color: DesignTokens.secondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.viajeCode,
                  style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 16, color: DesignTokens.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.apicultorNombre}  •  ${widget.localidad}',
                  style: TextStyle(fontSize: 12, color: DesignTokens.primary.withOpacity(0.5)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF7E7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_tambores.length} TCM',
              style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFFC68E17)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_box_rounded, size: 18, color: DesignTokens.secondary),
                const SizedBox(width: 8),
                Text('Nuevo Tambor', style: DesignTokens.headlineStyle().copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),

            // Código SENASA
            TextFormField(
              controller: _senasaController,
              decoration: _inputDecoration('CÓDIGO SENASA (11 DÍGITOS)', Icons.qr_code_rounded),
              keyboardType: TextInputType.number,
              maxLength: 11,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),

            // Peso Bruto + Tara
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brutoController,
                    decoration: _inputDecoration('PESO BRUTO (kg)', Icons.monitor_weight_rounded),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _taraController,
                    decoration: _inputDecoration('TARA (kg)', Icons.scale_rounded),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preview del Neto + Botón Agregar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: DesignTokens.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DesignTokens.secondary.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NETO', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFFC68E17))),
                      Text(
                        '${_netoActual.toStringAsFixed(1)} kg',
                        style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 18, color: DesignTokens.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _agregarTambor,
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: const Text('AGREGAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38),
      prefixIcon: Icon(icon, size: 18, color: DesignTokens.primary.withOpacity(0.4)),
      filled: true,
      fillColor: const Color(0xFFF7F7F7),
      counterText: '',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DesignTokens.secondary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildTamboresHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_rounded, size: 16, color: DesignTokens.primary),
          const SizedBox(width: 8),
          Text('Tambores Registrados', style: DesignTokens.headlineStyle().copyWith(fontSize: 15)),
          const Spacer(),
          Text('${_tambores.length} TAMBORES', style: DesignTokens.labelStyle().copyWith(fontSize: 9, color: Colors.black38)),
        ],
      ),
    );
  }

  Widget _buildEmptyTambores() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text('Ningún tambor registrado aún.\nCompletá el formulario y presioná AGREGAR.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black38, fontSize: 13)),
      ),
    );
  }

  Widget _buildTabla() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Header oscuro
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E302C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _th('#', 1),
                _th('SENASA', 4),
                _th('BRUTO', 2, right: true),
                _th('TARA', 2, right: true),
                _th('NETO', 2, right: true),
                const SizedBox(width: 28), // espacio para botón eliminar
              ],
            ),
          ),
          // Filas
          ...List.generate(_tambores.length, (i) => _buildFila(i)),
        ],
      ),
    );
  }

  Widget _th(String text, int flex, {bool right = false}) {
    return Expanded(
      flex: flex,
      child: Text(text,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontFamily: 'Work Sans', color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildFila(int index) {
    final t = _tambores[index];
    final isEven = index % 2 == 0;
    final neto = t['peso_neto'] as double;
    final bruto = t['peso_bruto'] as double;
    final tara = t['tara'] as double;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFFAFAFA) : Colors.white,
        border: index < _tambores.length - 1
            ? const Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))
            : null,
        borderRadius: index == _tambores.length - 1
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : null,
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Colors.black38))),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['senasa_codigo']?.toString() ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF424846)), overflow: TextOverflow.ellipsis),
                if (t['guardado'] == true)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                    child: Text('guardado', style: TextStyle(fontSize: 7, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text('${bruto.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF424846)))),
          Expanded(flex: 2, child: Text('${tara.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF424846)))),
          Expanded(
            flex: 2,
            child: Text(
              '${neto.toStringAsFixed(0)} kg',
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w800, color: DesignTokens.secondary),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.withOpacity(0.4)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => _eliminarTambor(index),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalesCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DesignTokens.primary, DesignTokens.primary.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildTotalItem('BRUTO TOTAL', _totalBruto, Colors.white.withOpacity(0.6)),
          _buildDivider(),
          _buildTotalItem('TARA TOTAL', _totalTara, Colors.white.withOpacity(0.6)),
          _buildDivider(),
          _buildTotalItem('NETO TOTAL', _totalNeto, DesignTokens.secondary),
        ],
      ),
    );
  }

  Widget _buildTotalItem(String label, double value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.5), letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(0)} kg',
            style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 16, color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 32, color: Colors.white.withOpacity(0.15), margin: const EdgeInsets.symmetric(horizontal: 4));
  }

  Widget _buildGuardarBtn() {
    return Container(
      width: MediaQuery.of(context).size.width - 40,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _guardarPesaje,
        icon: _saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_rounded, color: Colors.white),
        label: Text(
          _saving ? 'GUARDANDO...' : 'GUARDAR PESAJE (${_tambores.length} TCM)',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.secondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: DesignTokens.secondary.withOpacity(0.4),
        ),
      ),
    );
  }
}
