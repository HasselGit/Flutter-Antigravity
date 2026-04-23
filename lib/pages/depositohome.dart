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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A5D23),
        title: Text(
          'Panel de Depósito',
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
            const Icon(Icons.inventory_2_outlined, size: 80, color: Color(0xFF4A5D23)),
            const SizedBox(height: 20),
            Text(
              'Gestión de Stock y Cargas',
              style: GoogleFonts.interTight(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Módulo operativo en preparación.',
              style: GoogleFonts.inter(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
