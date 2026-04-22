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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF4F5F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF4F5F0),
          automaticallyImplyLeading: false,
          toolbarHeight: 120,
          flexibleSpace: FlexibleSpaceBar(
            title: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 15.0, right: 50.0, bottom: 10.0),
                child: Text(
                  'Encargado de Compras',
                  style: GoogleFonts.interTight(
                    color: const Color(0xFF2D2D2D),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
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
          ),
          elevation: 2,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    
                    if (context.mounted) {
                      context.go('/welcome');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Log Out',
                    style: GoogleFonts.interTight(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
