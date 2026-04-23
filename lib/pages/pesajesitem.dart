import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'pesajes_item_model.dart';
export 'pesajes_item_model.dart';

class PesajesItemWidget extends StatefulWidget {
  const PesajesItemWidget({
    super.key,
    this.paradaItemId,
  });

  /// Items por Parada
  final String? paradaItemId;

  static String routeName = 'PesajesItem';
  static String routePath = '/pesajesItem';

  @override
  State<PesajesItemWidget> createState() => _PesajesItemWidgetState();
}

class _PesajesItemWidgetState extends State<PesajesItemWidget> {
  late PesajesItemModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PesajesItemModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();
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
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primary,
          automaticallyImplyLeading: false,
          title: Text(
            'Page Title',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight:
                        FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: false,
          elevation: 2,
        ),
        body: SafeArea(
          top: true,
          child: FutureBuilder<List<ParadaItemsRow>>(
            future: ParadaItemsTable().querySingleRow(
              queryFn: (q) => q.eqOrNull(
                'id',
                widget!.paradaItemId,
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
              List<ParadaItemsRow> containerParadaItemsRowList = snapshot.data!;

              final containerParadaItemsRow =
                  containerParadaItemsRowList.isNotEmpty
                      ? containerParadaItemsRowList.first
                      : null;

              _model.brutoController ??= TextEditingController();
              _model.taraController ??= TextEditingController();

              double bruto = double.tryParse(_model.brutoController!.text) ?? 0;
              double tara = double.tryParse(_model.taraController!.text) ?? 0;
              double neto = bruto > tara ? bruto - tara : 0;

              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado de Capacidad
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: FlutterFlowTheme.of(context).primary),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.local_shipping, color: FlutterFlowTheme.of(context).primary),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Capacidad del Camión', style: FlutterFlowTheme.of(context).bodySmall),
                                  LinearProgressIndicator(
                                    value: 0.65, // Ejemplo: 65% lleno
                                    backgroundColor: Colors.grey[300],
                                    color: FlutterFlowTheme.of(context).primary,
                                  ),
                                  Text('6.500 kg / 10.000 kg (Libre: 3.500 kg)', 
                                    style: FlutterFlowTheme.of(context).labelSmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Text('Registro de Tambor', style: FlutterFlowTheme.of(context).headlineSmall),
                      SizedBox(height: 16),
                      // Escaneo SENASA
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _model.textController,
                              decoration: InputDecoration(
                                labelText: 'Código SENASA (11 dígitos)',
                                border: OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.qr_code_scanner),
                                  onPressed: () async {
                                    _model.scannedValue = await FlutterBarcodeScanner.scanBarcode(
                                      '#C62828', 'Cancelar', true, ScanMode.BARCODE);
                                    if (_model.scannedValue != '-1') {
                                      _model.textController?.text = _model.scannedValue!;
                                    }
                                  },
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 11,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      // Entradas de Peso
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _model.brutoController,
                              decoration: InputDecoration(
                                labelText: 'Peso Bruto (kg)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => safeSetState(() {}),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _model.taraController,
                              decoration: InputDecoration(
                                labelText: 'Tara (kg)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => safeSetState(() {}),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Resultado Neto
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('PESO NETO:', style: FlutterFlowTheme.of(context).titleMedium),
                            Text('${neto.toStringAsFixed(2)} Kg', 
                              style: FlutterFlowTheme.of(context).headlineMedium.copyWith(color: FlutterFlowTheme.of(context).secondary)),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      // Botones de Acción
                      FFButtonWidget(
                        onPressed: () async {
                          // Lógica para guardar pesaje
                        },
                        text: 'Confirmar Pesaje',
                        options: FFButtonOptions(
                          height: 50,
                          color: FlutterFlowTheme.of(context).primary,
                          textStyle: FlutterFlowTheme.of(context).titleSmall.copyWith(color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 12),
                      FFButtonWidget(
                        onPressed: () async {
                          // Lógica para registrar solo bultos (No obligatorio el peso)
                        },
                        text: 'Registrar sin pesar (Solo Bultos)',
                        options: FFButtonOptions(
                          height: 50,
                          color: Colors.transparent,
                          textStyle: FlutterFlowTheme.of(context).titleSmall.copyWith(color: FlutterFlowTheme.of(context).primary),
                          borderSide: BorderSide(color: FlutterFlowTheme.of(context).primary, width: 2),
                        ),
                      ),
                    ],
                  ),
                ),
              );

            },
          ),
        ),
      ),
    );
  }
}
