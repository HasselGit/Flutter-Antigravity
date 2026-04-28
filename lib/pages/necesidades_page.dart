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
    Map<String, dynamic>? selectedApicultor;
    String? selectedProducto;
    final cantidadController = TextEditingController();
    String selectedTipo = _tabController.index == 0 ? 'Recolección' : 'Distribución';

    // Lista de productos predefinidos (Demo)
    final List<String> productosDemo = [
      'Miel de Eucalipto',
      'Miel de Pradera',
      'Miel de Monte',
      'Miel Multiflora',
      'Miel de Azahar',
      'Tambores Vacíos',
      'Insumos Varios',
      'Alimento Proteico',
      'Cera Estampada',
    ];

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nueva Solicitud', style: TextStyle(fontFamily: 'Manrope', fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF08201A))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 20),
              
              // Apicultor Searchable Selector
              const Text('Apicultor', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final result = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (context) {
                      String searchQuery = '';
                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          final filteredApis = _apicultores.where((a) => a['nombre'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
                          return AlertDialog(
                            title: const Text('Buscar Apicultor'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    decoration: const InputDecoration(hintText: 'Nombre...', prefixIcon: Icon(Icons.search)),
                                    onChanged: (v) => setDialogState(() => searchQuery = v),
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filteredApis.length,
                                      itemBuilder: (context, i) => ListTile(
                                        title: Text(filteredApis[i]['nombre']),
                                        subtitle: Text(filteredApis[i]['localidad'] ?? ''),
                                        onTap: () => Navigator.pop(context, filteredApis[i]),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                  if (result != null) {
                    setModalState(() {
                      selectedApicultor = result;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_search_rounded, size: 20, color: const Color(0xFF08201A).withOpacity(0.5)),
                      const SizedBox(width: 12),
                      Text(selectedApicultor != null ? selectedApicultor!['nombre'] : 'Seleccionar apicultor...', 
                        style: TextStyle(color: selectedApicultor != null ? const Color(0xFF08201A) : Colors.black38)),
                    ],
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
                    selectedApicultor!['localidad'] ?? 'Sin localidad',
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
              
              // Producto Searchable Selector
              const Text('Producto', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) {
                      String searchQuery = '';
                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          final filteredProds = productosDemo.where((p) => p.toLowerCase().contains(searchQuery.toLowerCase())).toList();
                          return AlertDialog(
                            title: const Text('Buscar Producto'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    decoration: const InputDecoration(hintText: 'Nombre del producto...', prefixIcon: Icon(Icons.inventory_2_rounded)),
                                    onChanged: (v) => setDialogState(() => searchQuery = v),
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filteredProds.length,
                                      itemBuilder: (context, i) => ListTile(
                                        title: Text(filteredProds[i]),
                                        onTap: () => Navigator.pop(context, filteredProds[i]),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                  if (result != null) {
                    setModalState(() {
                      selectedProducto = result;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 20, color: const Color(0xFF08201A).withOpacity(0.5)),
                      const SizedBox(width: 12),
                      Text(selectedProducto ?? 'Seleccionar producto...', 
                        style: TextStyle(color: selectedProducto != null ? const Color(0xFF08201A) : Colors.black38)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedApicultor == null || cantidadController.text.isEmpty || selectedProducto == null) return;
                    await SupabaseService().createNecesidad({
                      'solicitud_codigo': 'SOL-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                      'apicultor_id': selectedApicultor!['id'],
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
                  child: const Text('GUARDAR SOLICITUD', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
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
        title: const Text('Gestión de Solicitudes', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, color: Color(0xFF08201A))),
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
        label: const Text('NUEVA SOLICITUD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
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
