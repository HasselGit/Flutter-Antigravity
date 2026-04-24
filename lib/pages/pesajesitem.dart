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
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: const Color(0xFFFBF9F8),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF08201A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Registro de Tambor',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: Color(0xFF08201A),
            ),
          ),
          actions: const [],
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Container(height: 1, color: Color(0x1408201A)),
          ),
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
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: theme.secondary),
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Capacidad Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.primary.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping_rounded, color: theme.secondary, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'CAPACIDAD OPERATIVA',
                                style: theme.labelSmall.override(
                                  fontFamily: 'Work Sans',
                                  fontWeight: FontWeight.bold,
                                  color: theme.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 8,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: 0.65,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.secondary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '6.500 kg / 10.000 kg (Libre: 3.500 kg)', 
                            style: theme.bodySmall.override(
                              fontFamily: 'Inter',
                              color: theme.secondaryText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Detalles del Pesaje',
                      style: theme.displaySmall.override(
                        fontFamily: 'Manrope',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // SENASA Code
                    TextFormField(
                      controller: _model.textController,
                      decoration: InputDecoration(
                        labelText: 'CÓDIGO SENASA (11 DÍGITOS)',
                        labelStyle: theme.labelSmall.override(
                          fontFamily: 'Work Sans',
                          fontWeight: FontWeight.bold,
                        ),
                        hintText: 'Ej: 12345678901',
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: theme.primary.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: theme.secondary),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.qr_code_scanner_rounded, color: theme.secondary),
                          onPressed: () async {
                            _model.scannedValue = await FlutterBarcodeScanner.scanBarcode(
                              '#7D5700', 'Cancelar', true, ScanMode.BARCODE);
                            if (_model.scannedValue != '-1') {
                              _model.textController?.text = _model.scannedValue!;
                            }
                          },
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                    ),
                    const SizedBox(height: 16),
                    // Weight Inputs
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _model.brutoController,
                            decoration: InputDecoration(
                              labelText: 'PESO BRUTO (KG)',
                              labelStyle: theme.labelSmall.override(
                                fontFamily: 'Work Sans',
                                fontWeight: FontWeight.bold,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: theme.primary.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: theme.secondary),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => safeSetState(() {}),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _model.taraController,
                            decoration: InputDecoration(
                              labelText: 'TARA (KG)',
                              labelStyle: theme.labelSmall.override(
                                fontFamily: 'Work Sans',
                                fontWeight: FontWeight.bold,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: theme.primary.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: theme.secondary),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => safeSetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Result Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: theme.secondary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PESO NETO',
                                style: theme.labelSmall.override(
                                  fontFamily: 'Work Sans',
                                  fontWeight: FontWeight.w900,
                                  color: theme.secondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${neto.toStringAsFixed(2)} KG', 
                                style: theme.displaySmall.override(
                                  fontFamily: 'Manrope',
                                  fontWeight: FontWeight.w800,
                                  color: theme.primary,
                                ),
                              ),
                            ],
                          ),
                          Icon(Icons.scale_rounded, color: theme.secondary, size: 32),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Action Buttons
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Lógica para guardar pesaje
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          'CONFIRMAR PESAJE',
                          style: theme.labelSmall.override(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () async {
                          // Lógica para registrar solo bultos
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'REGISTRAR SIN PESAR',
                          style: theme.labelSmall.override(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.bold,
                            color: theme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
