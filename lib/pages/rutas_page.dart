import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class RutasPageWidget extends StatefulWidget {
  const RutasPageWidget({super.key});

  @override
  State<RutasPageWidget> createState() => _RutasPageWidgetState();
}

class _RutasPageWidgetState extends State<RutasPageWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E352F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Gestión de Rutas Complejas', style: GoogleFonts.interTight(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 2,
        itemBuilder: (context, index) {
          final routes = [
            {
              'id': 'RUTA-PICO-ANGUIL', 
              'truck': 'SCANIA G-450', 
              'driver': 'Carlos Muse', 
              'status': 'En Curso',
              'details': 'Multiparada: Acopio -> Trenel -> Arata',
              'task_summary': 'Faltan 2 recolecciones de miel en Arata.',
              'progress': 0.6
            },
            {
              'id': 'RUTA-ROSA-CATRILO', 
              'truck': 'VOLVO FH 540', 
              'driver': 'Luis Espinosa', 
              'status': 'Planificada',
              'details': 'Entrega de Insumos y Recolección de Temporada',
              'task_summary': 'Pendiente aprobación de CEO por exceso de carga.',
              'progress': 0.0
            },
          ];
          final r = routes[index];
          
          return Card(
            margin: const EdgeInsets.only(bottom: 20),
            elevation: 8,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFC68E17).withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r['id'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF1E352F))),
                      _statusTag(r['status'] as String),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(r['details'] as String, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                  
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFC68E17)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r['task_summary'] as String, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E352F)))),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: r['progress'] as double,
                    backgroundColor: Colors.grey.shade100,
                    color: const Color(0xFF1E352F),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusTag(String s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF1E352F).withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
      child: Text(s.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF1E352F))),
    );
  }
}
