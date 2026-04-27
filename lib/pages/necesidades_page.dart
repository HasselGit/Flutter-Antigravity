import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/supabase_service.dart';

class NecesidadesPageWidget extends StatefulWidget {
  const NecesidadesPageWidget({super.key});

  @override
  State<NecesidadesPageWidget> createState() => _NecesidadesPageWidgetState();
}

class _NecesidadesPageWidgetState extends State<NecesidadesPageWidget> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _necesidades = [];
  List<Map<String, dynamic>> _apicultores = [];
  List<Map<String, dynamic>> _filteredNecesidades = [];
  bool _loading = true;
  String? _error;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
    _searchController.addListener(_filterNecesidades);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
          _filteredNecesidades = neceData;
          _apicultores = apiData;
          _loading = false;
        });
      }
    } catch (e) {
      print('NecesidadesPage: Error en _fetchData: $e');
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _filterNecesidades() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredNecesidades = _necesidades.where((n) {
        final apicultor = (n['apicultores']?['nombre'] ?? '').toString().toLowerCase();
        final localidad = (n['apicultores']?['localidad'] ?? '').toString().toLowerCase();
        final producto = (n['producto'] ?? '').toString().toLowerCase();
        return apicultor.contains(query) || localidad.contains(query) || producto.contains(query);
      }).toList();
    });
  }

  Future<void> _addNecesidad() async {
    String? selectedApicultor;
    String? selectedProducto = 'Miel';
    final cantidadController = TextEditingController();
    String selectedTipo = _tabController.index == 0 ? 'Recolección' : 'Distribución';

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
                      child: Text('${a['nombre']}'),
                    )).toList(),
                    onChanged: (v) {
                      setModalState(() {
                        selectedApicultor = v;
                      });
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Localidad (Auto)
              if (selectedApicultor != null) ...[
                const Text('Localidad Detectada', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF08201A).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _apicultores.firstWhere((a) => a['id'].toString() == selectedApicultor)['localidad'] ?? 'Sin localidad',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF08201A)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
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
              
              const SizedBox(height: 16),
              const Text('Producto', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => selectedProducto = v,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  hintText: 'Ej: Miel de Eucalipto',
                ),
                controller: TextEditingController(text: 'Miel'),
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF08201A),
          indicatorColor: const Color(0xFFFDBE49),
          tabs: const [
            Tab(text: 'RECOLECCIONES'),
            Tab(text: 'DISTRIBUCIONES'),
          ],
        ),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF08201A)))
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar apicultor, localidad o producto...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList('Recolección'),
                    _buildList('Distribución'),
                  ],
                ),
              ),
            ],
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

  Widget _buildList(String tipo) {
    final list = _filteredNecesidades.where((n) => n['tipo'] == tipo).toList();
    
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.black26),
            const SizedBox(height: 16),
            Text('No hay $tipo pendientes'.toLowerCase(), style: const TextStyle(color: Colors.black45)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final n = list[index];
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
                '${n['producto']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Manrope', fontSize: 16),
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
    );
  }
}
