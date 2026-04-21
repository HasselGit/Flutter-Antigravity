import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'logged_model.dart';
export 'logged_model.dart';

/// Logged
class LoggedWidget extends StatefulWidget {
  const LoggedWidget({super.key});

  static String routeName = 'Logged';
  static String routePath = '/logged';

  @override
  State<LoggedWidget> createState() => _LoggedWidgetState();
}

class _LoggedWidgetState extends State<LoggedWidget> {
  late LoggedModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoggedModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.qGerente = await VProfilesGerenteTable().queryRows(
        queryFn: (q) => q.eqOrNull(
          'auth_user_id',
          currentUserUid,
        ),
      );
      if (_model.qGerente != null && (_model.qGerente)!.isNotEmpty) {
        if (Navigator.of(context).canPop()) {
          context.pop();
        }
        context.pushNamed(GerenteHomeWidget.routeName);
      } else {
        _model.qCompras = await VProfilesComprasTable().queryRows(
          queryFn: (q) => q.eqOrNull(
            'auth_user_id',
            currentUserUid,
          ),
        );
        if (_model.qCompras != null && (_model.qCompras)!.isNotEmpty) {
          if (Navigator.of(context).canPop()) {
            context.pop();
          }
          context.pushNamed(ComprasHomeWidget.routeName);
        } else {
          _model.qDeposito = await VProfilesDepositoTable().queryRows(
            queryFn: (q) => q.eqOrNull(
              'auth_user_id',
              currentUserUid,
            ),
          );
          if (_model.qDeposito != null && (_model.qDeposito)!.isNotEmpty) {
            if (Navigator.of(context).canPop()) {
              context.pop();
            }
            context.pushNamed(DepositoHomeWidget.routeName);
          } else {
            _model.qChofer = await VProfilesChoferTable().queryRows(
              queryFn: (q) => q.eqOrNull(
                'auth_user_id',
                currentUserUid,
              ),
            );
            if (_model.qChofer != null && (_model.qChofer)!.isNotEmpty) {
              if (Navigator.of(context).canPop()) {
                context.pop();
              }
              context.pushNamed(ChoferHomeWidget.routeName);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Usuario sin rol asignado',
                    style: TextStyle(
                      color: FlutterFlowTheme.of(context).primaryText,
                    ),
                  ),
                  duration: Duration(milliseconds: 4000),
                  backgroundColor: FlutterFlowTheme.of(context).secondary,
                ),
              );
              if (Navigator.of(context).canPop()) {
                context.pop();
              }
              context.pushNamed(LoginWidget.routeName);
            }
          }
        }
      }
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
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [],
          ),
        ),
      ),
    );
  }
}
