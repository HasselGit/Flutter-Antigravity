import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import 'package:go_router/go_router.dart';

class ApicultorDetalleWidget extends StatefulWidget {
  final Map<String, dynamic> apicultor;
  const ApicultorDetalleWidget({super.key, required this.apicultor});

  @override
  State<ApicultorDetalleWidget> createState() => _ApicultorDetalleWidgetState();
}

class _ApicultorDetalleWidgetState extends State<ApicultorDetalleWidget> {
  bool _loading = true;
  List<Map<String, dynamic>> _operaciones = [];
  Map<String, Map<String, double>> _resumenProductos = {};

  @override
  void initState() {
    super.initState();
    _fetchOperaciones();
  }

  Future<void> _fetchOperaciones() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      // Buscamos todas las necesidades vinculadas a este apicultor
      // Nota: En el esquema, las necesidades se vinculan por apicultor_id o apicultor_nombre?
      // Revisando necesidades_page.dart, se guardan con 'apicultor_id'.
      final res = await client
          .from('necesidades')
          .select('*, paradas(*, viajes(*))')
          .eq('apicultor_id', widget.apicultor['id']);
      
      final ops = List<Map<String, dynamic>>.from(res);
      
      // Calcular resumen
      Map<String, Map<String, double>> resumen = {};
      for (var op in ops) {
        String prod = op['producto'] ?? 'Otros';
        String tipo = op['tipo'] ?? 'Desconocido';
        double cant = double.tryParse(op['cantidad_estimada']?.toString() ?? '0') ?? 0;
        
        resumen.putIfAbsent(prod, () => {});
        resumen[prod]![tipo] = (resumen[prod]![tipo] ?? 0) + cant;
      }

      if (mounted) {
        setState(() {
          _operaciones = ops;
          _resumenProductos = resumen;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.apicultor;
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Detalle de Apicultor', style: DesignTokens.headlineStyle()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DesignTokens.primary),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(a),
                const SizedBox(height: 32),
                Text('Resumen de Operaciones', style: DesignTokens.headlineStyle().copyWith(fontSize: 18)),
                const SizedBox(height: 16),
                _buildProductSummary(),
                const SizedBox(height: 32),
                Text('Historial Reciente', style: DesignTokens.headlineStyle().copyWith(fontSize: 18)),
                const SizedBox(height: 16),
                ..._operaciones.map((op) => _buildOperacionItem(op)).toList(),
                if (_operaciones.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No hay operaciones registradas aún.'),
                  )),
              ],
            ),
          ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> a) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: DesignTokens.primary.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: DesignTokens.primary, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.person_pin_rounded, color: DesignTokens.secondary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['nombre'] ?? 'Sin nombre', style: DesignTokens.headlineStyle().copyWith(fontSize: 20)),
                    Text(a['apicultor_codigo'] ?? 'S/C', style: DesignTokens.labelStyle()),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),
          _buildInfoRow(Icons.location_on_rounded, 'Localidad', a['localidad'] ?? 'S/D'),
          _buildInfoRow(Icons.map_rounded, 'Provincia', a['provincia'] ?? 'S/D'),
          _buildInfoRow(Icons.badge_rounded, 'CUIT/DNI', '${a['cuit'] ?? ''} / ${a['dni'] ?? ''}'),
          _buildInfoRow(Icons.assignment_ind_rounded, 'RENAPA', a['renapa'] ?? 'S/D'),
          _buildInfoRow(Icons.phone_rounded, 'Teléfono', a['telefono'] ?? 'S/D'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: DesignTokens.onSurfaceVariant.withOpacity(0.6)),
          const SizedBox(width: 12),
          Text('$label:', style: DesignTokens.bodyStyle().copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: DesignTokens.bodyStyle().copyWith(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildProductSummary() {
    if (_resumenProductos.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _resumenProductos.entries.map((e) {
        return Container(
          width: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.key, style: DesignTokens.labelStyle().copyWith(color: DesignTokens.primary)),
              const SizedBox(height: 8),
              ...e.value.entries.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(v.key, style: const TextStyle(fontSize: 10, color: DesignTokens.onSurfaceVariant)),
                    Text(v.value.toStringAsFixed(0), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              )).toList(),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOperacionItem(Map<String, dynamic> op) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            op['tipo'] == 'Recolección' ? Icons.download_rounded : Icons.upload_rounded,
            color: op['tipo'] == 'Recolección' ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(op['producto'] ?? 'Producto', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${op['tipo']} - ${op['cantidad_estimada']} ${op['unidad'] ?? ''}', style: const TextStyle(fontSize: 12, color: DesignTokens.onSurfaceVariant)),
              ],
            ),
          ),
          Text(op['estado'] ?? 'Pendiente', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
