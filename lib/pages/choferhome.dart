import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ChoferHomeWidget extends StatefulWidget {
  const ChoferHomeWidget({super.key});

  @override
  State<ChoferHomeWidget> createState() => _ChoferHomeWidgetState();
}

class _ChoferHomeWidgetState extends State<ChoferHomeWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E352F),
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mis Viajes Asignados', style: GoogleFonts.interTight(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            Text('CHOFER OPERATIVO', style: GoogleFonts.inter(color: const Color(0xFFC68E17), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client.from('viajes').stream(primaryKey: ['id']),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _buildError(snapshot.error.toString());
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final viajes = snapshot.data!;
          if (viajes.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: viajes.length,
            itemBuilder: (context, index) {
              final v = viajes[index];
              // Simulando desglose profesional de productos para el chofer
              return _buildChoferTripCard(v);
            },
          );
        },
      ),
    );
  }

  Widget _buildChoferTripCard(Map<String, dynamic> v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: () => context.push('/viajedetalle'),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('V-2026-CHOFER', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF1E352F))),
                  const Icon(Icons.local_shipping, color: Color(0xFFC68E17)),
                ],
              ),
              const SizedBox(height: 12),
              Text('RUTA: Gral. Pico -> Anguil -> Santa Rosa', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const Divider(height: 32),
              
              Text('RESUMEN DE CARGA ASIGNADA:', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 12),
              _itemRow('Cuadros Estándar', '150 u'),
              _itemRow('Cera Estampada', '45 kg'),
              _itemRow('Miel a Recolectar', '1.200 kg (aprox)'),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF4A5D23).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text('EN CURSO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF4A5D23))),
                  ),
                  Text('INICIAR HOJA DE RUTA', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFC68E17))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemRow(String name, String qty) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(qty, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF1E352F))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text('Sin viajes asignados para hoy', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildError(String err) {
    return Center(child: Padding(padding: const EdgeInsets.all(30), child: Text(err, style: const TextStyle(color: Colors.red))));
  }
}
