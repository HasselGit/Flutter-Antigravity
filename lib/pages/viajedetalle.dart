import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'viaje_detalle_model.dart';
export 'viaje_detalle_model.dart';

/// Detalle de Viaje
class ViajeDetalleWidget extends StatefulWidget {
  const ViajeDetalleWidget({
    super.key,
    required this.viajeId,
  });

  /// ViajeId
  final String? viajeId;

  static String routeName = 'ViajeDetalle';
  static String routePath = '/viajeDetalle';

  @override
  State<ViajeDetalleWidget> createState() => _ViajeDetalleWidgetState();
}

class _ViajeDetalleWidgetState extends State<ViajeDetalleWidget> {
  late ViajeDetalleModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ViajeDetalleModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.qViaje = await ViajesTable().queryRows(
        queryFn: (q) => q.eqOrNull(
          'id',
          widget!.viajeId,
        ),
      );
    });
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Color(0xFFF4F5F0),
        appBar: AppBar(
          backgroundColor: Color(0xFFF4F5F0),
          automaticallyImplyLeading: true,
          title: Text('Detalle de Viaje', style: FlutterFlowTheme.of(context).headlineMedium),
          actions: [
            IconButton(
              icon: Icon(Icons.map, color: FlutterFlowTheme.of(context).primary),
              onPressed: () async {
                // Abrir Google Maps con todos los puntos (simulado)
                await launchUrl(Uri.parse('https://www.google.com/maps/dir/-34.6037,-58.3816/-34.6137,-58.3916'));
              },
            ),
          ],
          elevation: 2,
        ),
        body: SafeArea(
          top: true,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(12, 0, 0, 0),
            child: FutureBuilder<List<VParadasConApicultorFfRow>>(
              future: VParadasConApicultorFfTable().queryRows(
                queryFn: (q) => q
                    .eqOrNull(
                      'viaje_id',
                      'ce224211-5239-4fa6-a3d3-384b837141e4',
                    )
                    .order('orden_secuencia', ascending: true),
              ),
              builder: (context, snapshot) {
                // Customize what your widget looks like when it's loading.
                if (!snapshot.hasData) {
                  return Center(
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          FlutterFlowTheme.of(context).primary,
                        ),
                      ),
                    ),
                  );
                }
                List<VParadasConApicultorFfRow>
                    listViewVParadasConApicultorFfRowList = snapshot.data!;

                return ListView.separated(
                  padding: EdgeInsets.zero,
                  scrollDirection: Axis.vertical,
                  itemCount: listViewVParadasConApicultorFfRowList.length,
                  separatorBuilder: (_, __) => SizedBox(height: 16),
                  itemBuilder: (context, listViewIndex) {
                    final listViewVParadasConApicultorFfRow =
                        listViewVParadasConApicultorFfRowList[listViewIndex];
                      return Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFFFAF9F6),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Color(0xFFC68E17), width: 1),
                            boxShadow: [BoxShadow(blurRadius: 4, color: Color(0x22000000), offset: Offset(0, 2))],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Indicador de Tipo
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: listViewVParadasConApicultorFfRow.tipo == 'Recolección' 
                                      ? Colors.green[100] : Colors.blue[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    listViewVParadasConApicultorFfRow.tipo == 'Recolección' 
                                      ? Icons.file_download : Icons.file_upload,
                                    color: listViewVParadasConApicultorFfRow.tipo == 'Recolección' 
                                      ? Colors.green : Colors.blue,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Parada ${listViewVParadasConApicultorFfRow.ordenSecuencia}: ${listViewVParadasConApicultorFfRow.tipo}',
                                        style: FlutterFlowTheme.of(context).titleMedium.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Apicultor: ${listViewVParadasConApicultorFfRow.apicultorNombre ?? '--'}',
                                        style: FlutterFlowTheme.of(context).bodyMedium,
                                      ),
                                      Text(
                                        'Localidad: ${listViewVParadasConApicultorFfRow.localidad ?? '--'}',
                                        style: FlutterFlowTheme.of(context).bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.navigation, color: FlutterFlowTheme.of(context).primary),
                                      onPressed: () async {
                                        // Abrir navegación GPS
                                        final url = 'google.navigation:q=${listViewVParadasConApicultorFfRow.localidad}';
                                        await launchUrl(Uri.parse(url));
                                      },
                                    ),
                                    Text('IR', style: FlutterFlowTheme.of(context).labelSmall),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
}
