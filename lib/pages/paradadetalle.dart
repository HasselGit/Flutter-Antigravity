import '../flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../components/agregaritem.dart';

class ParadaDetalleWidget extends StatefulWidget {
  const ParadaDetalleWidget({super.key, required this.paradaId});

  final String? paradaId;

  static String routeName = 'ParadaDetalle';
  static String routePath = '/paradaDetalle';

  @override
  State<ParadaDetalleWidget> createState() => _ParadaDetalleWidgetState();
}

class _ParadaDetalleWidgetState extends State<ParadaDetalleWidget> {
  // Stitch colors
  static const kPrimary = Color(0xFF08201A);
  static const kPrimaryContainer = Color(0xFF1E352F);
  static const kSecContainer = Color(0xFFFDBE49);
  static const kSurface = Color(0xFFFBF9F8);
  static const kSurfaceLow = Color(0xFFF5F3F3);
  static const kOnSurface = Color(0xFF1B1C1C);
  static const kOnSurfaceVariant = Color(0xFF424846);
  static const kOutlineVariant = Color(0xFFC2C8C4);

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cantidad actualizada'), duration: Duration(seconds: 1)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Operación en Parada',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: kPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_isEditingQuantities ? Icons.check_circle_rounded : Icons.edit_note_rounded, color: kPrimary),
            onPressed: () => setState(() => _isEditingQuantities = !_isEditingQuantities),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kPrimary.withOpacity(0.08)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              FutureBuilder<Map<String, dynamic>?>(
                future: widget.paradaId != null 
                  ? Supabase.instance.client.from('v_paradas_con_apicultor_ff').select().eq('id', widget.paradaId!).maybeSingle()
                  : Future.value(<String, dynamic>{}),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator(color: kSecContainer)),
                    );
                  }
                  final parada = snapshot.data ?? {};
                  final tipo = (parada['tipo']?.toString() ?? '').toLowerCase();
                  final isRecoleccion = tipo.contains('recolec');
  
                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kPrimary.withOpacity(0.06)),
                      boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: kPrimary.withOpacity(0.06),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isRecoleccion ? Icons.scale_rounded : Icons.inventory_2_rounded,
                                color: kPrimaryContainer, size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PARADA ${parada['orden_secuencia'] ?? '--'}',
                                    style: TextStyle(
                                      fontFamily: 'Work Sans',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      color: kOnSurfaceVariant.withOpacity(0.7),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    parada['apicultor_nombre'] ?? 'Sin Nombre',
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: kPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isRecoleccion ? const Color(0xFFD4F0E1) : const Color(0xFFD6E4FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isRecoleccion ? 'RECOLECCIÓN' : 'DISTRIBUCIÓN',
                                style: TextStyle(
                                  fontFamily: 'Work Sans',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  color: isRecoleccion ? const Color(0xFF1A6B43) : const Color(0xFF1565C0),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: kSecContainer, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              parada['localidad'] ?? 'Localidad no definida',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: kOnSurfaceVariant.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
  
              // Receiver selection section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kPrimary.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RESPONSABLE DE RECEPCIÓN',
                        style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, color: kOnSurfaceVariant, letterSpacing: 1),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _choiceChip('El Apicultor', _receptorTipo == 'Apicultor', () => setState(() => _receptorTipo = 'Apicultor')),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _choiceChip('Un Tercero', _receptorTipo == 'Tercero', () => setState(() => _receptorTipo = 'Tercero')),
                          ),
                        ],
                      ),
                      if (_receptorTipo == 'Tercero') ...[
                        const SizedBox(height: 20),
                        _inputField('Nombre Completo', _receptorNombreController, Icons.person_outline_rounded),
                        const SizedBox(height: 12),
                        _inputField('DNI / Identificación', _receptorDniController, Icons.badge_outlined),
                      ],
                    ],
                  ),
                ),
              ),
  
              const SizedBox(height: 20),
  
              // Items section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditingQuantities ? 'EDITAR CANTIDADES' : 'ITEMS REGISTRADOS',
                      style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, color: kOnSurfaceVariant, letterSpacing: 1),
                    ),
                    if (_isEditingQuantities)
                      const Text('Toca la cantidad para cambiar', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
  
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: widget.paradaId != null
                  ? Supabase.instance.client.from('parada_items').stream(primaryKey: ['id']).eq('parada_id', widget.paradaId!).order('id')
                  : const Stream.empty(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kSecContainer));
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: kOnSurfaceVariant.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          const Text('No hay items registrados', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: kOnSurfaceVariant)),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final itemId = item['id'].toString();
                      final cant = (item['cantidad'] as num?)?.toDouble() ?? 0.0;
  
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kPrimary.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(color: kPrimary.withOpacity(0.05), shape: BoxShape.circle),
                              child: const Icon(Icons.hexagon_rounded, color: kPrimaryContainer, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['producto_codigo'] ?? item['producto'] ?? 'Producto', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 14, color: kPrimary)),
                                  Text('${item['unidad'] ?? 'U'}: $cant', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: kOnSurfaceVariant.withOpacity(0.7))),
                                ],
                              ),
                            ),
                            if (_isEditingQuantities)
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
                                    onPressed: () => _updateItemQuantity(itemId, (cant - 1).clamp(0, 9999)),
                                  ),
                                  Text(cant.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                                    onPressed: () => _updateItemQuantity(itemId, cant + 1),
                                  ),
                                ],
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded, color: kOutlineVariant),
                                onPressed: () => context.push('/pesajesItem?paradaItemId=$itemId'),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Pass receptor info to remito page
                          final params = {
                            'paradaId': widget.paradaId,
                            'receptorTipo': _receptorTipo,
                            'receptorNombre': _receptorNombreController.text,
                            'receptorDni': _receptorDniController.text,
                          };
                          context.push(Uri(path: '/remito', queryParameters: params).toString());
                        },
                        icon: const Icon(Icons.receipt_long_rounded, color: kPrimary, size: 20),
                        label: const Text('GENERAR REMITO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 13, color: kPrimary, letterSpacing: 0.8)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSecContainer,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/pesajesItem?paradaId=${widget.paradaId}'),
                        icon: const Icon(Icons.scale_rounded, color: Colors.white, size: 20),
                        label: const Text('NUEVO PESAJE (TAMBOR)', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white, letterSpacing: 0.8)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7D5700),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                            builder: (context) => Padding(
                              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                              child: AgregarItemWidget(paradaId: widget.paradaId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, color: kPrimary, size: 20),
                        label: const Text('AGREGAR ITEM MANUAL', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 13, color: kPrimary, letterSpacing: 0.8)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kPrimary, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? kPrimary : kPrimary.withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 13, color: selected ? Colors.white : kPrimary),
          ),
        ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: kOnSurfaceVariant),
        filled: true,
        fillColor: kSurfaceLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
      ),
    );
  }
}
