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
      appBar: AppBar(
        title: Text('Depósito', style: GoogleFonts.interTight()),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/welcome');
            },
          )
        ],
      ),
      body: const Center(
        child: Text('Pantalla de Depósito'),
      ),
    );
  }
}
