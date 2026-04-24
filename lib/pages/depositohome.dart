import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class DepositoHomeWidget extends StatelessWidget {
  const DepositoHomeWidget({super.key});

  static String routeName = 'DepositoHome';
  static String routePath = '/depositoHome';

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
          'Panel de Depósito',
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory_2_rounded, size: 80, color: theme.primary),
              ),
              const SizedBox(height: 32),
              Text(
                'Gestión de Stock y Cargas',
                style: theme.displaySmall.override(
                  fontFamily: 'Manrope',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Módulo operativo en preparación estratégica.',
                textAlign: TextAlign.center,
                style: theme.bodyMedium.override(
                  fontFamily: 'Inter',
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'PRÓXIMAMENTE',
                  style: theme.labelSmall.override(
                    fontFamily: 'Work Sans',
                    fontWeight: FontWeight.bold,
                    color: theme.secondary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
