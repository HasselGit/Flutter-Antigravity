import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: Text('Detalle de Parada', style: GoogleFonts.interTight()),
        backgroundColor: const Color(0xFFFAF9F6),
        elevation: 2,
      ),
      body: SafeArea(
        child: Column(
          children: [
            FutureBuilder<Map<String, dynamic>?>(
              future: widget.paradaId != null 
                ? Supabase.instance.client.from('v_paradas_con_apicultor_ff').select().eq('id', widget.paradaId!).maybeSingle()
                : Future.value(<String, dynamic>{}),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final parada = snapshot.data ?? {};
                return Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  color: const Color(0xFFFAF9F6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Parada: ${parada['orden_secuencia'] ?? '--'}', style: GoogleFonts.inter()),
                      Text('Tipo: ${parada['tipo'] ?? '--'}', style: GoogleFonts.inter()),
                      Text('Localidad: ${parada['localidad'] ?? '--'}', style: GoogleFonts.inter()),
                      Text('Apicultor: ${parada['apicultor_nombre'] ?? '--'}', style: GoogleFonts.inter()),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: widget.paradaId != null
                  ? Supabase.instance.client.from('parada_items').stream(primaryKey: ['id']).eq('parada_id', widget.paradaId!).order('id')
                  : const Stream.empty(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data ?? [];
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text('Producto: ${item['producto_codigo'] ?? '--'}'),
                        subtitle: Text('Cantidad: ${item['cantidad'] ?? '--'}'),
                        trailing: const Icon(Icons.chevron_right),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => Padding(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: AgregarItemWidget(paradaId: widget.paradaId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: const Text('Agregar Item', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
