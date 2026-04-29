import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../backend/supabase_service.dart';

class PesajesPageWidget extends StatefulWidget {
  const PesajesPageWidget({super.key});

  @override
  State<PesajesPageWidget> createState() => _PesajesPageWidgetState();
}

class _PesajesPageWidgetState extends State<PesajesPageWidget> {
  List<Map<String, dynamic>> _pesajes = [];
  bool _loading = true;

  static const kPrimary = Color(0xFF08201A);
  static const kSecContainer = Color(0xFFFDBE49);
  static const kSurface = Color(0xFFFBF9F8);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('pesajes')
          .select('*, profiles(nombre, apellido)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _pesajes = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F3),
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Control de Pesajes',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: kPrimary),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kSecContainer))
          : _pesajes.isEmpty
              ? const Center(child: Text('No hay registros de pesaje.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _pesajes.length,
                  itemBuilder: (context, index) {
                    final p = _pesajes[index];
                    return _buildPesajeCard(p);
                  },
                ),
    );
  }

  Widget _buildPesajeCard(Map<String, dynamic> p) {
    final bruto = p['peso_bruto']?.toString() ?? '0';
    final neto = p['peso_neto']?.toString() ?? '0';
    final tara = p['tara']?.toString() ?? '0';
    final fecha = DateTime.tryParse(p['created_at']?.toString() ?? '') ?? DateTime.now();
    final fechaStr = DateFormat('dd/MM/yyyy HH:mm').format(fecha);
    final chofer = p['profiles'] != null ? '${p['profiles']['nombre']} ${p['profiles']['apellido']}' : 'S/D';
    final tambor = p['nro_tambor']?.toString() ?? 'S/N';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tambor: $tambor', style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimary)),
              Text(fechaStr, style: const TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _infoCol('BRUTO', '$bruto Kg'),
              _infoCol('TARA', '$tara Kg'),
              _infoCol('NETO', '$neto Kg'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 14, color: Colors.black45),
              const SizedBox(width: 4),
              Text('Registrado por: $chofer', style: const TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCol(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kPrimary)),
      ],
    );
  }
}
