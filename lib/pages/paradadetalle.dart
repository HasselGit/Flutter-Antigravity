import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../components/agregaritem.dart';
import '../backend/design_tokens.dart';

class ParadaDetalleWidget extends StatefulWidget {
  const ParadaDetalleWidget({super.key, required this.paradaId});

  final String? paradaId;

  static String routeName = 'ParadaDetalle';
  static String routePath = '/paradaDetalle';

  @override
  State<ParadaDetalleWidget> createState() => _ParadaDetalleWidgetState();
}

class _ParadaDetalleWidgetState extends State<ParadaDetalleWidget> {
  String? _receptorTipo = 'Apicultor'; // 'Apicultor' o 'Tercero'
  final _receptorNombreController = TextEditingController();
  final _receptorDniController = TextEditingController();
  bool _isEditingQuantities = false;
  Map<String, double> _editedQuantities = {};

  @override
  void dispose() {
    _receptorNombreController.dispose();
    _receptorDniController.dispose();
    super.dispose();
  }

  Future<void> _updateItemQuantity(String itemId, double qty) async {
    try {
      await Supabase.instance.client.from('parada_items').update({'cantidad': qty}).eq('id', itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cantidad actualizada'), duration: Duration(seconds: 1)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Operación en Parada',
          style: DesignTokens.headlineStyle().copyWith(fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_isEditingQuantities ? Icons.check_circle_rounded : Icons.edit_note_rounded, color: DesignTokens.primary),
            onPressed: () => setState(() => _isEditingQuantities = !_isEditingQuantities),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              FutureBuilder<Map<String, dynamic>?>(
                future: widget.paradaId != null 
                  ? Supabase.instance.client.from('paradas').select('id, orden_secuencia, tipo, ubicacion, localidad, bruto_kg, neto_kg').eq('id', widget.paradaId!).maybeSingle().then((data) {
                      if (data != null) {
                        data['apicultor_nombre'] = data['ubicacion']; // Map to legacy field name used in UI
                      }
                      return data;
                    })
                  : Future.value(<String, dynamic>{}),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: DesignTokens.secondary)),
                    );
                  }
                  final p = snapshot.data;
                  if (p == null) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No se encontró la parada')));
                  
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(p),
                        const SizedBox(height: 32),
                        _buildItemsSection(),
                        const SizedBox(height: 32),
                        _buildDigitalRemitoForm(p),
                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: DesignTokens.primary.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: DesignTokens.secondary, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'PARADA #${p['orden_secuencia'] ?? '?' }',
                  style: const TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1),
                ),
              ),
              Text(
                (p['tipo'] ?? 'Operación').toString().toUpperCase(),
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(p['apicultor_nombre'] ?? 'Sin Nombre', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on_rounded, size: 14, color: DesignTokens.secondary.withOpacity(0.8)),
              const SizedBox(width: 4),
              Text(p['localidad'] ?? 'Sin Localidad', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('RESUMEN DE PRODUCTOS', style: DesignTokens.labelStyle()),
            TextButton.icon(
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => AgregarItemWidget(paradaId: widget.paradaId!),
                );
                setState(() {});
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Agregar'),
              style: TextButton.styleFrom(foregroundColor: DesignTokens.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client.from('parada_items').stream(primaryKey: ['id']).eq('parada_id', widget.paradaId!).order('id'),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final items = snapshot.data!;
            if (items.isEmpty) return _buildEmptyItems();
            
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return _buildItemCard(item);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyItems() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, color: DesignTokens.primary.withOpacity(0.2), size: 40),
          const SizedBox(height: 12),
          const Text('No hay productos registrados', style: TextStyle(color: DesignTokens.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: DesignTokens.surface, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.shopping_bag_rounded, color: DesignTokens.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['producto_codigo'] ?? 'Producto', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: DesignTokens.primary)),
                Text(item['unidad'] ?? 'unidades', style: const TextStyle(fontSize: 12, color: DesignTokens.onSurfaceVariant)),
              ],
            ),
          ),
          if (_isEditingQuantities)
            SizedBox(
              width: 80,
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(isDense: true, border: UnderlineInputBorder()),
                controller: TextEditingController(text: item['cantidad'].toString()),
                onSubmitted: (val) {
                  final qty = double.tryParse(val);
                  if (qty != null) _updateItemQuantity(item['id'], qty);
                },
              ),
            )
          else
            Text(
              item['cantidad'].toString(),
              style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 18, color: DesignTokens.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildDigitalRemitoForm(Map<String, dynamic> p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('REGISTRO DE ENTREGA (REMITO)', style: DesignTokens.labelStyle()),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              _buildDropdownField('Tipo de Receptor', _receptorTipo, ['Apicultor', 'Tercero'], (val) => setState(() => _receptorTipo = val)),
              const SizedBox(height: 16),
              _buildInputField('Nombre Completo', _receptorNombreController, Icons.person_rounded),
              const SizedBox(height: 16),
              _buildInputField('DNI / CUIT', _receptorDniController, Icons.badge_rounded),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _generarRemito(p),
                  style: DesignTokens.secondaryButtonStyle,
                  child: const Text('GENERAR REMITO DIGITAL'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: DesignTokens.primary.withOpacity(0.5)),
        filled: true,
        fillColor: DesignTokens.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: DesignTokens.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _generarRemito(Map<String, dynamic> p) async {
    // Implementación de generación de remito
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generando remito digital...')));
  }
}
