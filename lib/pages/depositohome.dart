import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/design_tokens.dart';

class DepositoHomeWidget extends StatefulWidget {
  const DepositoHomeWidget({super.key});

  @override
  State<DepositoHomeWidget> createState() => _DepositoHomeWidgetState();
}

class _DepositoHomeWidgetState extends State<DepositoHomeWidget> {
  List<Map<String, dynamic>> _viajesPlanificados = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final dataRaw = await Supabase.instance.client
          .from('viajes')
          .select('id, viaje_codigo, vehiculo_codigo, chofer_id, estado, fecha, descripcion')
          .eq('estado', 'Planificado')
          .order('fecha', ascending: true);

      final List<Map<String, dynamic>> viajes = List<Map<String, dynamic>>.from(dataRaw);
      
      for (var v in viajes) {
        if (v['chofer_id'] != null) {
          try {
            final p = await Supabase.instance.client.from('profiles').select('nombre, apellido').eq('id', v['chofer_id']).maybeSingle();
            v['profiles'] = p;
          } catch (_) {}
        }
        try {
          final paradasRaw = await Supabase.instance.client.from('paradas').select('id, tipo, localidad, orden_secuencia').eq('viaje_id', v['id']);
          final List<Map<String, dynamic>> paradas = List<Map<String, dynamic>>.from(paradasRaw);
          for (var p in paradas) {
            final items = await Supabase.instance.client.from('parada_items').select('id, producto_codigo, cantidad, unidad').eq('parada_id', p['id']);
            p['parada_items'] = items;
          }
          v['paradas'] = paradas;
        } catch (_) { v['paradas'] = []; }
      }

      if (mounted) {
        setState(() {
          _viajesPlanificados = viajes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmarCarga(Map<String, dynamic> viaje) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Carga'),
        content: Text('¿Confirma que el vehículo ${viaje['vehiculo_codigo']} ha sido cargado según lo planificado para el viaje ${viaje['viaje_codigo']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CONFIRMAR')),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await Supabase.instance.client.from('viajes').update({'estado': 'Cargado'}).eq('id', viaje['id']);
        _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viaje marcado como CARGADO'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        title: Text('Módulo de Depósito', style: DesignTokens.headlineStyle().copyWith(fontSize: 17)),
        iconTheme: const IconThemeData(color: DesignTokens.primary),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
        : _viajesPlanificados.isEmpty
          ? const Center(child: Text('No hay cargas pendientes.'))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _viajesPlanificados.length,
              itemBuilder: (context, i) => _buildCargaCard(_viajesPlanificados[i]),
            ),
    );
  }

  Widget _buildCargaCard(Map<String, dynamic> v) {
    final chofer = v['profiles'] != null ? '${v['profiles']['nombre']} ${v['profiles']['apellido']}' : 'S/D';
    final paradas = List<Map<String, dynamic>>.from(v['paradas'] ?? []);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(v['viaje_codigo'] ?? 'S/C', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: DesignTokens.primary, fontFamily: 'Manrope')),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text(v['vehiculo_codigo'] ?? 'S/V', style: const TextStyle(color: Color(0xFF7D5700), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Chofer: $chofer', style: const TextStyle(color: DesignTokens.onSurfaceVariant, fontSize: 13)),
                const Divider(height: 32),
                const Text('LISTA DE CARGA (DISTRIBUCIONES):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: DesignTokens.primary, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                ...paradas.where((p) => p['tipo'] == 'Distribución').map((p) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ${p['localidad']}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ...(p['parada_items'] as List? ?? []).map((it) => Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Text('- ${it['producto_codigo']}: ${it['cantidad']} ${it['unidad']}', style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    const SizedBox(height: 8),
                  ],
                )).toList(),
                if (!paradas.any((p) => p['tipo'] == 'Distribución'))
                  const Text('No hay distribuciones programadas.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _confirmarCarga(v),
              style: DesignTokens.secondaryButtonStyle.copyWith(
                shape: WidgetStateProperty.all(const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))))
              ),
              child: const Text('CONFIRMAR CARGA LISTA'),
            ),
          ),
        ],
      ),
    );
  }
}
