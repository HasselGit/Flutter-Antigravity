import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'welcome_page_model.dart';
export 'welcome_page_model.dart';

class WelcomePageWidget extends StatefulWidget {
  const WelcomePageWidget({super.key});

  static String routeName = 'WelcomePage';
  static String routePath = '/WelcomePage';

  @override
  State<WelcomePageWidget> createState() => _WelcomePageWidgetState();
}

class _WelcomePageWidgetState extends State<WelcomePageWidget> {
  late WelcomePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WelcomePageModel());
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
        body: Stack(
          children: [
            // Light Technical Background
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: AssetImage('assets/images/fondoWelcome_4.png'),
                ),
              ),
            ),
            // Content
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),
                      // Fluid Logo (Restored Visibility)
                      Image.asset(
                        'assets/images/logo_Geologistica_Verde.png',
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'GeoLogística',
                        style: GoogleFonts.interTight(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E352F),
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Highlighted Text with secondary color
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: const Color(0xFFC68E17), width: 2),
                          ),
                        ),
                        child: Text(
                          'TECNOLOGÍA Y LOGÍSTICA APÍCOLA',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF4A5D23).withOpacity(0.8),
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      const Spacer(flex: 4),
                      // New Premium Button with Guaranteed Gold Border
                      Padding(
                        padding: const EdgeInsets.only(bottom: 60),
                        child: SizedBox(
                          width: double.infinity,
                          height: 65,
                          child: ElevatedButton(
                            onPressed: () => context.pushNamed('Login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E352F),
                              foregroundColor: Colors.white,
                              elevation: 10,
                              shadowColor: Colors.black45,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(
                                  color: Color(0xFFC68E17),
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(
                              'INGRESAR AL SISTEMA',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
