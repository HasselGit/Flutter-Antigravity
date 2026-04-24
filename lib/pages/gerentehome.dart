import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class GerenteHomeWidget extends StatelessWidget {
  const GerenteHomeWidget({super.key});

  static String routeName = 'GerenteHome';
  static String routePath = '/gerenteHome';

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Gerencia Estratégica',
          style: TextStyle(
            fontFamily: 'Manrope',
            color: Color(0xFF08201A),
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFF08201A)),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/');
              },
            ),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF08201A).withOpacity(0.08)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visión Ejecutiva',
                style: theme.displayLarge.override(
                  fontFamily: 'Manrope',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: theme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Análisis de datos y toma de decisiones en tiempo real.',
                style: theme.bodyMedium.override(
                  fontFamily: 'Inter',
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 40),
              // Main Analytics Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.primary.withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withOpacity(0.03),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.secondary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.analytics_rounded, size: 48, color: theme.secondary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Panel de Reportes',
                      style: theme.titleSmall.override(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.bold,
                        color: theme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Próximamente: Visualización de KPIs, rendimiento de rutas y proyecciones de cosecha.',
                      textAlign: TextAlign.center,
                      style: theme.bodyMedium.override(
                        fontFamily: 'Inter',
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'EN PREPARACIÓN',
                        style: theme.labelSmall.override(
                          fontFamily: 'Work Sans',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
