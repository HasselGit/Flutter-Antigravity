import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'agregar_item_model.dart';
export 'agregar_item_model.dart';

/// Boton de Agregar Item
class AgregarItemWidget extends StatefulWidget {
  const AgregarItemWidget({
    super.key,
    required this.paradaId,
  });

  /// paradaId
  final String? paradaId;

  @override
  State<AgregarItemWidget> createState() => _AgregarItemWidgetState();
}

class _AgregarItemWidgetState extends State<AgregarItemWidget> {
  late AgregarItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AgregarItemModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Text(
          'Agregar Item',
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                font: GoogleFonts.inter(
                  fontWeight:
                      FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
                letterSpacing: 0.0,
                fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
              ),
        ),
        FutureBuilder<List<ProductosRow>>(
          future: ProductosTable().queryRows(
            queryFn: (q) => q,
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
            List<ProductosRow> dropDownProductosRowList = snapshot.data!;

            return FlutterFlowDropDown<String>(
              key: ValueKey('Productos'),
              controller: _model.dropDownValueController ??=
                  FormFieldController<String>(null),
              options: dropDownProductosRowList
                  .map((e) => valueOrDefault<String>(
                        e.descripcion,
                        '--',
                      ))
                  .toList(),
              onChanged: (val) =>
                  safeSetState(() => _model.dropDownValue = val),
              width: 200,
              height: 40,
              textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
              hintText: 'Seleccionar Producto',
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: FlutterFlowTheme.of(context).secondaryText,
                size: 24,
              ),
              fillColor: FlutterFlowTheme.of(context).secondaryBackground,
              elevation: 2,
              borderColor: Colors.transparent,
              borderWidth: 0,
              borderRadius: 8,
              margin: EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
              hidesUnderline: true,
              isOverButton: false,
              isSearchable: false,
              isMultiSelect: false,
            );
          },
        ),
        Container(
          width: 200,
          child: TextFormField(
            controller: _model.textController,
            focusNode: _model.textFieldFocusNode,
            autofocus: false,
            enabled: true,
            obscureText: false,
            decoration: InputDecoration(
              isDense: true,
              labelStyle: FlutterFlowTheme.of(context).labelMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight:
                          FlutterFlowTheme.of(context).labelMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).labelMedium.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).labelMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelMedium.fontStyle,
                  ),
              hintText: 'TextField',
              hintStyle: FlutterFlowTheme.of(context).labelMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight:
                          FlutterFlowTheme.of(context).labelMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).labelMedium.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).labelMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelMedium.fontStyle,
                  ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Color(0x00000000),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Color(0x00000000),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: FlutterFlowTheme.of(context).error,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: FlutterFlowTheme.of(context).error,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: FlutterFlowTheme.of(context).secondaryBackground,
            ),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight:
                        FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
            cursorColor: FlutterFlowTheme.of(context).primaryText,
            enableInteractiveSelection: true,
            validator: _model.textControllerValidator.asValidator(context),
          ),
        ),
        FFButtonWidget(
          onPressed: () async {
            _model.prodSel = await ProductosTable().queryRows(
              queryFn: (q) => q.eqOrNull(
                'descripcion',
                _model.dropDownValue,
              ),
            );
            await ParadaItemsTable().insert({
              'parada_id': widget!.paradaId,
              'producto_codigo': _model.prodSel?.elementAtOrNull(0)?.codigo,
              'cantidad': double.tryParse(_model.textController.text),
            });
            Navigator.pop(context);

            context.goNamed(
              ParadaDetalleWidget.routeName,
              queryParameters: {
                'paradaId': serializeParam(
                  widget!.paradaId,
                  ParamType.String,
                ),
              }.withoutNulls,
              extra: <String, dynamic>{
                '__transition_info__': TransitionInfo(
                  hasTransition: true,
                  transitionType: PageTransitionType.fade,
                  duration: Duration(milliseconds: 0),
                ),
              },
            );

            safeSetState(() {});
          },
          text: 'Guardar',
          options: FFButtonOptions(
            height: 40,
            padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
            iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
            color: FlutterFlowTheme.of(context).primary,
            textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                  font: GoogleFonts.interTight(
                    fontWeight:
                        FlutterFlowTheme.of(context).titleSmall.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleSmall.fontStyle,
                  ),
                  color: Colors.white,
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).titleSmall.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                ),
            elevation: 0,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }
}
