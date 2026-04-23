import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class ViajesPageWidget extends StatefulWidget {
  const ViajesPageWidget({super.key});

  @override
  State<ViajesPageWidget> createState() => _ViajesPageWidgetState();
}

class _ViajesPageWidgetState extends State<ViajesPageWidget> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

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
        title: Text('Gestión de Viajes', style: GoogleFonts.interTight(fontWeight: FontWeight.bold, color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFC68E17),
          indicatorWeight: 4,
          tabs: const [
            Tab(text: 'PLANIFICADOS'),
            Tab(text: 'EN CURSO'),
            Tab(text: 'TERMINADOS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTripList('Planificado'),
          _buildTripList('En Curso'),
          _buildTripList('Terminado'),
        ],
      ),
    );
  }

  Widget _buildTripList(String status) {
    final trips = [
      {
        'id': 'V-1024',
        'status': 'Planificado',
        'date': '24/04',
        'items': [
          {'name': 'Cuadros Estándar', 'qty': '150', 'unit': 'u'},
          {'name': 'Cera Estampada', 'qty': '40', 'unit': 'kg'},
          {'name': 'Alimentadores', 'qty': '20', 'unit': 'u'},
        ],
        'apicultores': ['Juan Pérez', 'Gómez Hnos'],
      },
      {
        'id': 'V-2000',
        'status': 'En Curso',
        'date': '23/04',
        'items': [
          {'name': 'Miel Multiflora', 'qty': '1.250', 'unit': 'kg'},
          {'name': 'Cera Opérculo', 'qty': '85', 'unit': 'kg'},
          {'name': 'Tambores Vacíos', 'qty': '12', 'unit': 'u'},
        ],
        'apicultores': ['Cooperativa P.', 'Estancia La Paz'],
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 20),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: InkWell(
            onTap: () => context.push('/viajedetalle'),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('VIAJE ${trip['id']}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF1E352F))),
                      _statusChip(trip['status'] as String),
                    ],
                  ),
                  const Divider(height: 30),
                  Text('RESUMEN DE CARGA:', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  ... (trip['items'] as List).map((item) => _buildProductRow(item)).toList(),
                  const SizedBox(height: 20),
                  Text('APICULTORES:', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text((trip['apicultores'] as List).join(' • '), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E352F))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductRow(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFC68E17), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(item['name'], style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${item['qty']} ${item['unit']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF1E352F))),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF1E352F).withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF1E352F))),
    );
  }
}
