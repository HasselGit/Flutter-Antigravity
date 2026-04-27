import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ComprasHomeWidget extends StatefulWidget {
  const ComprasHomeWidget({super.key});

  @override
  State<ComprasHomeWidget> createState() => _ComprasHomeWidgetState();
}

class _ComprasHomeWidgetState extends State<ComprasHomeWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: const Color(0xFFFBF9F8),
          automaticallyImplyLeading: false,
          toolbarHeight: 70,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Panel de Compras',
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
                  if (context.mounted) {
                    context.go('/');
                  }
                },
              ),
            ),
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
                  'Gestión de Adquisiciones',
                  style: theme.displayLarge.override(
                    fontFamily: 'Manrope',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: theme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Control central de miel y suministros apícolas.',
                  style: theme.bodyMedium.override(
                    fontFamily: 'Inter',
                    color: theme.secondaryText,
                  ),
                ),
                const SizedBox(height: 32),
                // Featured Module Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.primary.withOpacity(0.05),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withOpacity(0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.secondary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shopping_cart_rounded, size: 40, color: theme.secondary),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Gestión de Necesidades',
                        style: theme.titleSmall.override(
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.bold,
                          color: theme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gestione las solicitudes de recolección y distribución de miel.',
                        textAlign: TextAlign.center,
                        style: theme.bodyMedium.override(
                          fontFamily: 'Inter',
                          color: theme.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => context.push('/necesidades'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.secondary,
                            foregroundColor: theme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('GESTIONAR NECESIDADES', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
