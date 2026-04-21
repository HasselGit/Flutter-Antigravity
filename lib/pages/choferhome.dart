import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'chofer_home_model.dart';
export 'chofer_home_model.dart';

/// Home Chofer
class ChoferHomeWidget extends StatefulWidget {
  const ChoferHomeWidget({super.key});

  static String routeName = 'ChoferHome';
  static String routePath = '/choferHome';

  @override
  State<ChoferHomeWidget> createState() => _ChoferHomeWidgetState();
}

class _ChoferHomeWidgetState extends State<ChoferHomeWidget> {
  late ChoferHomeModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChoferHomeModel());
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
            title: Align(
              alignment: AlignmentDirectional(-1, 1),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(15, 0, 50, 0),
                child: Text(
                  'Chofer',
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).displayLarge.override(
                        font: GoogleFonts.interTight(
                          fontWeight: FontWeight.w900,
                          fontStyle: FlutterFlowTheme.of(context)
                              .displayLarge
                              .fontStyle,
                        ),
                        color: Color(0xFF2D2D2D),
                        fontSize: 34,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w900,
                        fontStyle:
                            FlutterFlowTheme.of(context).displayLarge.fontStyle,
                      ),
                ),
              ),
            ),
            background: Opacity(
              opacity: 0.3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.asset(
                  'assets/images/fonfoWelcome_4.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            centerTitle: true,
            expandedTitleScale: 1.0,
          ),
          elevation: 2,
        ),
        body: SafeArea(
          top: true,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          FFButtonWidget(
                            onPressed: () async {
                              GoRouter.of(context).prepareAuthEvent();
                              await authManager.signOut();
                              GoRouter.of(context).clearRedirectLocation();

                              context.goNamedAuth(
                                  WelcomePageWidget.routeName, context.mounted);
                            },
                            text: 'Log Out',
                            options: FFButtonOptions(
                              height: 40,
                              padding:
                                  EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                              iconPadding:
                                  EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                              color: FlutterFlowTheme.of(context).primary,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    color: Colors.white,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                              elevation: 0,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
