import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class ViajeDetalleWidget extends StatefulWidget {
  final String? viajeId;
  const ViajeDetalleWidget({super.key, this.viajeId});

  @override
  State<ViajeDetalleWidget> createState() => _ViajeDetalleWidgetState();
}

class _ViajeDetalleWidgetState extends State<ViajeDetalleWidget> {
  String estadoViaje = 'Planificado'; // Planificado, En Curso, Terminado
  double capacidadMaximaKg = 5000.0;
  double cargaActualKg = 1800.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F0),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusControl(),
                  const SizedBox(height: 20),
                  _buildManagementDashboard(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('HOJA DE RUTA Y PESAJES'),
                  _buildStopItinerary(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showManagementForm(context),
        backgroundColor: const Color(0xFF1E352F),
        elevation: 8,
        icon: const Icon(Icons.add_business, color: Color(0xFFC68E17)),
        label: Text('GESTIÓN DE CARGA', 
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 12)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 80.0,
      pinned: true,
      backgroundColor: const Color(0xFF1E352F),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text('CONTROL DE RUTA', 
          style: GoogleFonts.interTight(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
      ),
    );
  }

  Widget _buildStatusControl() {
    Color statusColor = estadoViaje == 'En Curso' ? Colors.orange : (estadoViaje == 'Terminado' ? Colors.green : Colors.blue);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ESTADO DEL VIAJE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor)),
              Text(estadoViaje.toUpperCase(), style: GoogleFonts.interTight(fontSize: 18, fontWeight: FontWeight.w900, color: statusColor)),
            ],
          ),
          if (estadoViaje != 'Terminado')
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (estadoViaje == 'Planificado') {
                    estadoViaje = 'En Curso';
                  } else if (estadoViaje == 'En Curso') {
                    estadoViaje = 'Terminado';
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(estadoViaje == 'Planificado' ? 'INICIAR VIAJE' : 'FINALIZAR VIAJE', 
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _buildManagementDashboard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CAPACIDAD DEL CAMIÓN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text('${(cargaActualKg / capacidadMaximaKg * 100).toInt()}% OCUPADO', style: GoogleFonts.interTight(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1E352F))),
                ],
              ),
              const Icon(Icons.local_shipping_outlined, color: Color(0xFFC68E17), size: 28),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: cargaActualKg / capacidadMaximaKg,
            backgroundColor: const Color(0xFFF4F5F0),
            color: (cargaActualKg / capacidadMaximaKg) > 0.9 ? Colors.red : const Color(0xFFC68E17),
            borderRadius: BorderRadius.circular(10),
            minHeight: 8,
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _dashItem('1.800', 'kg', 'CARGA ACTUAL'),
              _dashItem('3.200', 'kg', 'DISPONIBLE'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dashItem(String val, String unit, String label) {
    return Column(
      children: [
        RichText(text: TextSpan(children: [
          TextSpan(text: val, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1E352F))),
          TextSpan(text: ' $unit', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFC68E17))),
        ])),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStopItinerary() {
    final stops = [
      {
        'api': 'Juan Pérez',
        'localidad': 'Santa Rosa',
        'creator': 'COMPRAS',
        'hasPesaje': true,
        'bruto': '1.250',
        'neto': '1.180',
        'items': [
          {'name': 'Alimentadores 2L', 'qty': '250', 'unit': 'u'},
          {'name': 'Cera Estampada', 'qty': '120', 'unit': 'kg'},
        ]
      },
      {
        'api': 'Gómez Hnos.',
        'localidad': 'Anguil',
        'creator': 'GERENCIA',
        'hasPesaje': true,
        'bruto': '2.100',
        'neto': '1.950',
        'items': [
          {'name': 'Miel Multiflora', 'qty': '1.950', 'unit': 'kg'},
        ]
      },
    ];

    return Column(
      children: stops.map((stop) {
        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFC68E17), shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stop['api'] as String, style: GoogleFonts.interTight(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1E352F))),
                        Text('Localidad: ${stop['localidad']}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF1E352F).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(stop['creator'] as String, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF1E352F))),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (stop['hasPesaje'] as bool) _buildPesajeInfo(stop['bruto'] as String, stop['neto'] as String),
              const SizedBox(height: 10),
              ...(stop['items'] as List).map((i) => _itemDetailCard(i)).toList(),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPesajeInfo(String bruto, String neto) {
    return Container(
      margin: const EdgeInsets.only(left: 24, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFC68E17).withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFC68E17).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.scale_outlined, color: Color(0xFFC68E17), size: 18),
          const SizedBox(width: 12),
          _pesajeItem('BRUTO', bruto),
          const SizedBox(width: 24),
          _pesajeItem('NETO', neto),
        ],
      ),
    );
  }

  Widget _pesajeItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFFC68E17))),
        Text('$val kg', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF1E352F))),
      ],
    );
  }

  Widget _itemDetailCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(left: 24, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Row(
        children: [
          Expanded(
            child: Text(item['name'], style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E352F))),
          ),
          Text('${item['qty']} ${item['unit']}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFFC68E17))),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String t) {
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: Text(t, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)));
  }

  void _showManagementForm(BuildContext context) {
    String selectedApi = 'Juan Pérez';
    String selectedOperacion = 'Recolección';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GESTIÓN DE CARGA', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20, color: const Color(0xFF1E352F))),
              const SizedBox(height: 20),
              _formLabel('SELECCIONAR PARADA / APICULTOR'),
              _dropdown(['Juan Pérez', 'Gómez Hnos.', 'Apiarios del Sur'], selectedApi, (v) => setModalState(() => selectedApi = v!)),
              const SizedBox(height: 12),
              _formLabel('LOCALIDAD (AUTO)'),
              _inputField(selectedApi == 'Juan Pérez' ? 'Santa Rosa' : (selectedApi == 'Gómez Hnos.' ? 'Anguil' : 'Toay'), enabled: false),
              const SizedBox(height: 12),
              _formLabel('OPERACIÓN'),
              _dropdown(['Distribución', 'Recolección', 'Ambas'], selectedOperacion, (v) => setModalState(() => selectedOperacion = v!)),
              const SizedBox(height: 12),
              _formLabel('CANTIDAD / KG (PESO ESTIMADO)'),
              _inputField('Ej: 500', isNumeric: true),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    // Simulación de validación de capacidad
                    if (cargaActualKg + 3500 > capacidadMaximaKg) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: Colors.red, content: Text('¡ERROR! CAPACIDAD DEL CAMIÓN EXCEDIDA. NO SE PUEDE CARGAR.')),
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  }, 
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E352F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), 
                  child: const Text('CONFIRMAR CARGA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formLabel(String l) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey)));

  Widget _dropdown(List<String> items, String current, Function(String?) onChange) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFFF4F5F0), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
          onChanged: onChange,
        ),
      ),
    );
  }

  Widget _inputField(String hint, {bool enabled = true, bool isNumeric = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: enabled ? const Color(0xFFF4F5F0) : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      child: Text(hint, style: GoogleFonts.inter(color: enabled ? Colors.black87 : Colors.black45, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
