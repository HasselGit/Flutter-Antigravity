import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViajeDetalleWidget extends StatefulWidget {
  const ViajeDetalleWidget({super.key, required this.viajeId});

  final String? viajeId;

  static String routeName = 'ViajeDetalle';
  static String routePath = '/viajeDetalle';

  @override
  State<ViajeDetalleWidget> createState() => _ViajeDetalleWidgetState();
}

class _ViajeDetalleWidgetState extends State<ViajeDetalleWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF4F5F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF4F5F0),
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              children: [
                Opacity(
                  opacity: 0.3,
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAF9F6),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 15, top: 40),
                  child: FutureBuilder<Map<String, dynamic>?>(
                    future: widget.viajeId != null 
                        ? Supabase.instance.client
                            .from('viajes')
                            .select()
                            .eq('id', widget.viajeId!)
                            .maybeSingle()
                        : Future.value(<String, dynamic>{}),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      
                      final viajeData = snapshot.data ?? {};
                      final viajeCodigo = viajeData['viaje_codigo']?.toString() ?? '--';

                      return Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              'Detalle de Viaje',
                              style: GoogleFonts.interTight(
                                color: const Color(0xFF2D2D2D),
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            viajeCodigo,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF4A5D23),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          elevation: 2,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: widget.viajeId != null
                  ? Supabase.instance.client
                      .from('v_paradas_con_apicultor_ff')
                      .select()
                      .eq('viaje_id', widget.viajeId!)
                      .order('orden_secuencia', ascending: true)
                  : Future.value([]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final paradas = snapshot.data ?? [];

                return ListView.separated(
                  itemCount: paradas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final parada = paradas[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF9F6),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 8,
                            color: Color(0x33000000),
                            offset: Offset(0, 2),
                          )
                        ],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFFC68E17),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Parada:', parada['orden_secuencia']?.toString() ?? '0', context),
                          _buildDetailRow('Tipo:', parada['tipo']?.toString() ?? '-', context),
                          _buildDetailRow('Localidad:', parada['localidad']?.toString() ?? '-', context),
                          _buildDetailRow('Apicultor:', parada['apicultor_nombre']?.toString() ?? '--', context),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF2D2D2D),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(0xFF4A5D23),
            ),
          ),
        ],
      ),
    );
  }
}
