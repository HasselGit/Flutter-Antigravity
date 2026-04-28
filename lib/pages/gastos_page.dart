import '../flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import '../backend/supabase_service.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class GastosPageWidget extends StatefulWidget {
  const GastosPageWidget({super.key});

  @override
  State<GastosPageWidget> createState() => _GastosPageWidgetState();
}

class _GastosPageWidgetState extends State<GastosPageWidget> {
  List<Map<String, dynamic>> _gastos = [];
  bool _loading = true;

  // Stitch colors
  static const kPrimary = Color(0xFF08201A);
  static const kSecContainer = Color(0xFFFDBE49);
  static const kSurface = Color(0xFFFBF9F8);
  static const kOnSurfaceVariant = Color(0xFF424846);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final data = await SupabaseService().getGastos();
    if (mounted) {
      setState(() {
        _gastos = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Gestión de Gastos',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: kPrimary),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kSecContainer))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _gastos.length,
              itemBuilder: (context, index) {
                final g = _gastos[index];
                return _buildGastoCard(g);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGastoDialog(),
        backgroundColor: kPrimary,
        icon: const Icon(Icons.add_a_photo_rounded, color: kSecContainer),
        label: const Text('NUEVO GASTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildGastoCard(Map<String, dynamic> g) {
    final tipo = g['tipo_gasto'] ?? 'Gasto';
    final importe = g['importe']?.toString() ?? '0';
    final fecha = DateTime.tryParse(g['fecha']?.toString() ?? '') ?? DateTime.now();
    final fechaStr = DateFormat('dd/MM/yyyy').format(fecha);
    final chofer = g['profiles'] != null ? '${g['profiles']['nombre']} ${g['profiles']['apellido']}' : 'S/D';
    final viaje = g['viajes']?['viaje_codigo'] ?? 'Sin viaje';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kSecContainer.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(tipo.toUpperCase(), style: const TextStyle(color: Color(0xFF7D5700), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Text('\$ $importe', style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: kPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 14, color: kOnSurfaceVariant),
              const SizedBox(width: 6),
              Text(chofer, style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant)),
              const Spacer(),
              const Icon(Icons.calendar_today_rounded, size: 14, color: kOnSurfaceVariant),
              const SizedBox(width: 6),
              Text(fechaStr, style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, size: 14, color: kOnSurfaceVariant),
              const SizedBox(width: 6),
              Text('Viaje: $viaje', style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddGastoDialog() {
    // Placeholder for form dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo Gasto'),
        content: const Text('Formulario de ingreso de gastos con foto de ticket.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CERRAR')),
        ],
      ),
    );
  }
}
