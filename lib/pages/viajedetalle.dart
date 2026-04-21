import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
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
          automaticallyImplyLeading: false,
          actions: [],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              children: [
                Opacity(
                  opacity: 0.3,
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Color(0xFFFAF9F6),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(15, 0, 0, 0),
                  child: FutureBuilder<List<ViajesRow>>(
                    future: ViajesTable().querySingleRow(
                      queryFn: (q) => q.eqOrNull(
                        'id',
                        'ce224211-5239-4fa6-a3d3-384b837141e4',
                      ),
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
                      List<ViajesRow> columnViajesRowList = snapshot.data!;

                      final columnViajesRow = columnViajesRowList.isNotEmpty
                          ? columnViajesRowList.first
                          : null;

                      return Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: AlignmentDirectional(-1, 1),
                            child: Text(
                              'Detalle de Viaje',
                              textAlign: TextAlign.start,
                              style: FlutterFlowTheme.of(context)
                                  .displayLarge
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .displayLarge
                                          .fontStyle,
                                    ),
                                    color: Color(0xFF2D2D2D),
                                    fontSize: 28,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .fontStyle,
                                  ),
                            ),
                          ),
                          Text(
                            valueOrDefault<String>(
                              columnViajesRow?.viajeCodigo,
                              '--',
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color: Color(0xFF4A5D23),
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            centerTitle: true,
            expandedTitleScale: 1.0,
          ),
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
                      padding: EdgeInsetsDirectional.fromSTEB(12, 14, 12, 14),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: Color(0xFFFAF9F6),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 8,
                              color: Color(0x33000000),
                              offset: Offset(
                                0,
                                2,
                              ),
                            )
                          ],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Color(0xFFC68E17),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding:
                                  EdgeInsetsDirectional.fromSTEB(0, 20, 0, 0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Text(
                                        'Parada: ',
                                        style: FlutterFlowTheme.of(context)
                                            .headlineLarge
                                            .override(
                                              font: GoogleFonts.interTight(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .headlineLarge
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .headlineLarge
                                                        .fontStyle,
                                              ),
                                              color: Color(0xFF2D2D2D),
                                              fontSize: 20,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .headlineLarge
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .headlineLarge
                                                      .fontStyle,
                                            ),
                                      ),
                                      Text(
                                        valueOrDefault<String>(
                                          listViewVParadasConApicultorFfRow
                                              .ordenSecuencia
                                              ?.toString(),
                                          '0',
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              color: Color(0xFF4A5D23),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Text(
                                        'Tipo: ',
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              color: Color(0xFF2D2D2D),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                      Text(
                                        valueOrDefault<String>(
                                          listViewVParadasConApicultorFfRow
                                              .tipo,
                                          '-',
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              color: Color(0xFF4A5D23),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Text(
                                        'Localidad: ',
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              color: Color(0xFF2D2D2D),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                      Text(
                                        valueOrDefault<String>(
                                          listViewVParadasConApicultorFfRow
                                              .localidad,
                                          '-',
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              color: Color(0xFF4A5D23),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Text(
                                        'Apicultor: ',
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              color: Color(0xFF2D2D2D),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                      Text(
                                        valueOrDefault<String>(
                                          listViewVParadasConApicultorFfRow
                                              .apicultorNombre,
                                          '--',
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              color: Color(0xFF4A5D23),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
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
