import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

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
      final data = await Supabase.instance.client
          .from('viajes')
          .select('*, profiles(nombre, apellido)')
          .eq('estado', 'Planificado')
          .order('fecha', ascending: true);

      if (mounted) {
        setState(() {
          _viajesPlanificados = List<Map<String, dynamic>>.from(data);
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
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F8),
        elevation: 0,
        title: const Text('Módulo de Depósito', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, color: Color(0xFF08201A))),
        iconTheme: const IconThemeData(color: Color(0xFF08201A)),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Viajes para Cargar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF08201A))),
                    Text('Confirme la salida física de mercadería de planta.', style: TextStyle(color: Colors.black.withOpacity(0.5))),
                  ],
                ),
              ),
              Expanded(
                child: _viajesPlanificados.isEmpty 
                  ? const Center(child: Text('No hay viajes planificados pendientes de carga.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _viajesPlanificados.length,
                      itemBuilder: (context, index) {
                        final v = _viajesPlanificados[index];
                        final chofer = v['profiles'] ?? {};
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF08201A).withOpacity(0.05)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(v['viaje_codigo'] ?? 'S/C', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12)),
                                      child: Text(v['vehiculo_codigo'] ?? 'N/A', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Chofer: ${chofer['nombre']} ${chofer['apellido']}'),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _confirmarCarga(v),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF08201A),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text('CONFIRMAR CARGA Y SALIDA'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
    );
  }
}
