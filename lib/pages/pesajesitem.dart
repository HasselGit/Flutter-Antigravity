import '../backend/supabase/supabase.dart';
import '../backend/design_tokens.dart';
import '../flutter_flow/flutter_flow_util.dart' hide Supabase;
import 'dart:ui';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/supabase_service.dart';
import 'package:go_router/go_router.dart';

import 'pesajes_item_model.dart';
export 'pesajes_item_model.dart';

class PesajesItemWidget extends StatefulWidget {
  const PesajesItemWidget({
    super.key,
    this.paradaItemId,
    this.paradaId,
  });

  final String? paradaItemId;
  final String? paradaId;

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
        backgroundColor: DesignTokens.surfaceLow,
        appBar: AppBar(
          backgroundColor: DesignTokens.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Registro de Tambor',
            style: DesignTokens.headlineStyle().copyWith(fontSize: 17),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08)),
          ),
        ),
        body: SafeArea(
          top: true,
          child: FutureBuilder<List<ParadaItemsRow>>(
            future: ParadaItemsTable().querySingleRow(
              queryFn: (q) => q.eqOrNull(
                'id',
                widget.paradaItemId,
              ),
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: DesignTokens.secondary),
                );
              }
              List<ParadaItemsRow> containerParadaItemsRowList = snapshot.data!;

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
                        color: DesignTokens.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_shipping_rounded, color: DesignTokens.secondary, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'CAPACIDAD OPERATIVA',
                                style: DesignTokens.labelStyle().copyWith(fontSize: 10),
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
                                  color: DesignTokens.secondary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '6.500 kg / 10.000 kg (Libre: 3.500 kg)', 
                            style: TextStyle(fontFamily: 'Inter', color: DesignTokens.onSurfaceVariant, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Detalles del Pesaje',
                      style: DesignTokens.headlineStyle().copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 24),
                    // SENASA Code
                    TextFormField(
                      controller: _model.textController,
                      decoration: InputDecoration(
                        labelText: 'CÓDIGO SENASA (11 DÍGITOS)',
                        labelStyle: DesignTokens.labelStyle().copyWith(fontSize: 10),
                        hintText: 'Ej: 12345678901',
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: DesignTokens.secondary),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded, color: DesignTokens.secondary),
                          onPressed: () async {
                            _model.scannedValue = await FlutterBarcodeScanner.scanBarcode(
                              '#C68E17', 'Cancelar', true, ScanMode.BARCODE);
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
                              labelStyle: DesignTokens.labelStyle().copyWith(fontSize: 10),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: DesignTokens.secondary),
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
                              labelStyle: DesignTokens.labelStyle().copyWith(fontSize: 10),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: DesignTokens.secondary),
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
                        color: DesignTokens.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: DesignTokens.secondary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PESO NETO',
                                style: DesignTokens.labelStyle(color: DesignTokens.secondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${neto.toStringAsFixed(2)} KG', 
                                style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, color: DesignTokens.primary, fontSize: 28),
                              ),
                            ],
                          ),
                          const Icon(Icons.scale_rounded, color: DesignTokens.secondary, size: 32),
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
                          final codigoSenasa = _model.textController?.text ?? '';
                          if (codigoSenasa.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese el Código SENASA')));
                            return;
                          }
                          try {
                            final bruto = double.tryParse(_model.brutoController?.text ?? '0') ?? 0.0;
                            final tara = double.tryParse(_model.taraController?.text ?? '0') ?? 0.0;
                            final neto = bruto - tara;

                            await SupabaseService().createParadaItem({
                              if (widget.paradaId != null) 'parada_id': widget.paradaId,
                              'producto_codigo': codigoSenasa,
                              'cantidad': 1,
                              'peso_kg': neto,
                            });
                            
                            try {
                              await SupabaseService().createPesaje({
                                'parada_id': widget.paradaId,
                                'senasa_id': codigoSenasa,
                                'peso_bruto': bruto,
                                'tara': tara,
                                'peso_neto': neto,
                              });
                            } catch (_) {}

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesaje guardado'), backgroundColor: Colors.green));
                              context.pop();
                            }
                          } catch (e) {
                            print('PesajesItem: Error al guardar: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
                            }
                          }
                        },
                        style: DesignTokens.secondaryButtonStyle,
                        child: const Text('CONFIRMAR PESAJE'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () async {
                          try {
                            final codigoSenasa = _model.textController?.text ?? 'Bulto';
                            await SupabaseService().createParadaItem({
                              if (widget.paradaId != null) 'parada_id': widget.paradaId,
                              'producto_codigo': codigoSenasa,
                              'cantidad': 1,
                            });
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bulto registrado'), backgroundColor: Colors.green));
                              context.pop();
                            }
                          } catch (e) {
                            print('PesajesItem: Error al registrar: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al registrar: $e'), backgroundColor: Colors.red));
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: DesignTokens.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'REGISTRAR SIN PESAR',
                          style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, color: DesignTokens.primary),
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
