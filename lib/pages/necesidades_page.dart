import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../backend/supabase_service.dart';

class NecesidadesPageWidget extends StatefulWidget {
  const NecesidadesPageWidget({super.key});

  @override
  State<NecesidadesPageWidget> createState() => _NecesidadesPageWidgetState();
}

class _NecesidadesPageWidgetState extends State<NecesidadesPageWidget> {
  List<Map<String, dynamic>> _necesidades = [];
  List<Map<String, dynamic>> _apicultores = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = SupabaseService();
      final neceData = await service.getAllNecesidades();
      final apiData = await service.getApicultores();

      if (mounted) {
        setState(() {
          _necesidades = neceData;
          _apicultores = apiData;
          _loading = false;
        });
      }
    } catch (e) {
      print('NecesidadesPage: Error en _fetchData: $e');
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _addNecesidad() async {
    String? selectedApicultor;
    String? selectedProducto = 'Miel';
    final cantidadController = TextEditingController();
    String selectedTipo = 'Recolección';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFBF9F8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nueva Necesidad', style: TextStyle(fontFamily: 'Manrope', fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF08201A))),
              const SizedBox(height: 20),
              
              // Apicultor Select
              const Text('Apicultor', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedApicultor,
                    hint: const Text('Seleccionar apicultor'),
                    items: _apicultores.map((a) => DropdownMenuItem(
                      value: a['id'].toString(),
                      child: Text('${a['nombre']} (${a['localidad']})'),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedApicultor = v),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tipo', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedTipo,
                              items: ['Recolección', 'Distribución'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (v) => setModalState(() => selectedTipo = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cant. Est. (Kg)', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
                        const SizedBox(height: 8),
                        TextField(
                          controller: cantidadController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            hintText: 'Ej: 500',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedApicultor == null || cantidadController.text.isEmpty) return;
                    await SupabaseService().createNecesidad({
                      'apicultor_id': selectedApicultor,
                      'producto': selectedProducto,
                      'cantidad': double.tryParse(cantidadController.text) ?? 0,
                      'tipo': selectedTipo,
                      'estado': 'Pendiente',
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      _fetchData();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF08201A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('GUARDAR NECESIDAD', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F8),
        elevation: 0,
        title: const Text('Gestión de Necesidades', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, color: Color(0xFF08201A))),
        iconTheme: const IconThemeData(color: Color(0xFF08201A)),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF08201A)))
        : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _necesidades.length,
                itemBuilder: (context, index) {
                  final n = _necesidades[index];
                  final api = n['apicultores'] ?? {};
                  final estado = n['estado'] ?? 'Pendiente';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        '${n['tipo']} - ${n['producto']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Manrope'),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${api['nombre'] ?? 'Sin nombre'} • ${api['localidad'] ?? 'Sin loc.'}'),
                          Text('${n['cantidad']} Kg estimados', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF08201A))),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: estado == 'Pendiente' ? const Color(0xFFFDEFCC) : const Color(0xFFD4F0E1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          estado.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: estado == 'Pendiente' ? const Color(0xFF7D5700) : const Color(0xFF1A6B43),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNecesidad,
        backgroundColor: const Color(0xFFFDBE49),
        foregroundColor: const Color(0xFF08201A),
        icon: const Icon(Icons.add_rounded),
        label: const Text('NUEVA NECESIDAD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
      ),
    );
  }
}
