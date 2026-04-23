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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFC68E17), // Gold/Mustard for Gerencia
        title: Text(
          'Panel de Gerencia',
          style: GoogleFonts.interTight(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/');
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, size: 80, color: Color(0xFFC68E17)),
            const SizedBox(height: 20),
            Text(
              'Reportes y Decisiones',
              style: GoogleFonts.interTight(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Módulo estratégico en preparación.',
              style: GoogleFonts.inter(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
