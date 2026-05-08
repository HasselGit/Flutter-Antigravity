import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/design_tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../backend/supabase_service.dart';
import '../backend/apicultores_data.dart';

class ApicultorDetalleWidget extends StatefulWidget {
  final Map<String, dynamic> apicultor;
  const ApicultorDetalleWidget({super.key, required this.apicultor});

  @override
  State<ApicultorDetalleWidget> createState() => _ApicultorDetalleWidgetState();
}

class _ApicultorDetalleWidgetState extends State<ApicultorDetalleWidget> {
  bool _loading = true;
  String _debugInfo = 'Cargando debug...';
  List<Map<String, dynamic>> _pendientes = [];
  List<Map<String, dynamic>> _historial = [];
  Map<String, Map<String, double>> _resumenDetallado = {}; // Product -> {Tipo: Total}
  double _maxTotal = 1.0;

  @override
  void initState() {
    super.initState();
    _refreshApicultorData();
    _fetchDetailedData();
  }

  Future<void> _refreshApicultorData() async {
    try {
      final code = widget.apicultor['apicultor_codigo'] ?? widget.apicultor['id'];
      if (code == null) return;
      
      // Intentamos buscar por apicultor_codigo ya que es el identificador único del GSheet
      final fullData = await Supabase.instance.client
          .from('apicultores')
          .select('id, nombre, localidad, apicultor_codigo, provincia, dni, cuit, renapa, telefono')
          .eq('apicultor_codigo', code)
          .maybeSingle();
          
      if (fullData != null && mounted) {
        setState(() {
          widget.apicultor.addAll(fullData);
        });
      } else {
        // Segundo fallback: Buscar en la lista local de 104 apicultores
        final localData = ApicultoresData.fallbackApicultores.firstWhere(
          (a) => a['apicultor_codigo'] == code,
          orElse: () => {},
        );
        if (localData.isNotEmpty && mounted) {
          setState(() {
            widget.apicultor.addAll(localData);
          });
        }
      }
    } catch (e) {
      print('Error refreshing apicultor data: $e');
    }
  }

  Future<void> _fetchDetailedData() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      final apiId = widget.apicultor['apicultor_codigo'] ?? widget.apicultor['id'];
      
      // Manejar diferentes formatos de ID (ej: A01887 vs 1887)
      String alternateId = apiId;
      if (apiId.startsWith('A')) {
        alternateId = apiId.replaceAll(RegExp(r'^A0*'), '');
      } else {
        alternateId = 'A${apiId.padLeft(5, '0')}';
      }

      print('DEBUG: Buscando solicitudes para apicultor_id: $apiId o $alternateId');

      // 1. Fetch Solicitudes (Filtro en memoria ultra-robusto)
      final allSolsRes = await client.from('solicitudes').select('*');
      final List<Map<String, dynamic>> allSols = List<Map<String, dynamic>>.from(allSolsRes);
      
      final pendientes = allSols.where((s) {
        final sid = s['apicultor_id']?.toString() ?? '';
        
        // Match ESTRICTO por ID o por Código (únicos e irrepetibles)
        return sid == apiId || sid == alternateId || sid.contains(apiId) || apiId.contains(sid);
      }).toList();

      _debugInfo = '';
      
      // 2. Fetch Remitos and their related Parada/Items for Historial
      final remitosRes = await client
          .from('remitos')
          .select('*, paradas(tipo, localidad, parada_items(producto_codigo, cantidad, unidad))')
          .or('apicultor_id.eq.$apiId,apicultor_id.eq.$alternateId')
          .order('created_at', ascending: false);
      
      final remitos = List<Map<String, dynamic>>.from(remitosRes);
      
      // 3. Process Historial and Resumen
      List<Map<String, dynamic>> historial = [];
      Map<String, Map<String, double>> resumen = {};
      double maxT = 0;

      for (var rem in remitos) {
        final parada = rem['paradas'] ?? {};
        final items = List<Map<String, dynamic>>.from(parada['parada_items'] ?? []);
        final tipo = parada['tipo'] ?? 'Operación';
        
        for (var item in items) {
          final prod = item['producto_codigo'] ?? 'S/D';
          final cant = double.tryParse(item['cantidad']?.toString() ?? '0') ?? 0;
          
          historial.add({
            'fecha': rem['created_at'],
            'tipo': tipo,
            'producto': prod,
            'cantidad': cant,
            'unidad': item['unidad'] ?? 'kg',
            'remito': rem['remito_codigo'],
          });

          resumen.putIfAbsent(prod, () => {});
          resumen[prod]![tipo] = (resumen[prod]![tipo] ?? 0) + cant;
          
          double prodTotal = resumen[prod]!.values.reduce((a, b) => a + b);
          if (prodTotal > maxT) maxT = prodTotal;
        }
      }

      if (mounted) {
        setState(() {
          _pendientes = List<Map<String, dynamic>>.from(pendientes);
          _historial = historial.take(10).toList();
          _resumenDetallado = resumen;
          _maxTotal = maxT > 0 ? maxT : 1.0;
          _loading = false;
        });
        print('UI UPDATE: _pendientes has ${_pendientes.length} items');
      }
    } catch (e) {
      print('ApicultorDetalle: Error fetching detailed data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.apicultor;
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DesignTokens.primary, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: DesignTokens.primary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hive_outlined, size: 24, color: DesignTokens.primary),
            const SizedBox(width: 8),
            Text('Perfil de Apicultor', 
              style: DesignTokens.headlineStyle().copyWith(fontSize: 16, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
        : RefreshIndicator(
            onRefresh: _fetchDetailedData,
            color: DesignTokens.secondary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildProfileHeader(a),
                  const SizedBox(height: 24),
                  _buildEditProfileButton(),
                  const SizedBox(height: 24),
                  _buildInfoGrid(a),
                  
                  const SizedBox(height: 40),
                  _buildSectionHeader('Operaciones Pendientes', null),
                  const SizedBox(height: 16),
                  if (_pendientes.isEmpty)
                    _buildEmptyState()
                  else
                    ..._pendientes.map((s) => _buildPendienteCard(s)).toList(),

                  // Sección: Resumen de Operaciones (Solo si hay remitos)
                  if (_resumenDetallado.isNotEmpty) ...[
                    const SizedBox(height: 40),
                    _buildSectionHeader('Resumen de Operaciones', 'VER REPORTE DETALLADO'),
                    const SizedBox(height: 16),
                    _buildProductSummary(),
                  ],

                  // Sección: Historial Reciente (Solo si hay remitos)
                  if (_historial.isNotEmpty) ...[
                    const SizedBox(height: 40),
                    _buildSectionHeader('Historial Reciente', null, showIcons: true),
                    const SizedBox(height: 16),
                    _buildRecentHistoryTable(),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSolicitudModal,
        backgroundColor: DesignTokens.secondary,
        elevation: 8,
        child: const Icon(Icons.add_rounded, color: DesignTokens.primary, size: 32),
      ),
    );
  }

  void _showAddSolicitudModal() async {
    final apicultor = widget.apicultor;
    String? selectedTipo = 'Recolección';
    String? selectedProducto;
    final cantidadController = TextEditingController();
    List<Map<String, dynamic>> productos = [];

    // Cargar productos igual que en necesidades_page
    try {
      final prodData = await Supabase.instance.client.from('productos').select('descripcion, codigo, unidad').order('descripcion');
      productos = List<Map<String, dynamic>>.from(prodData);
    } catch (e) {
      print('Error cargando productos: $e');
    }

    if (productos.isEmpty) {
      productos = [
        {'codigo': 'TCM', 'descripcion': 'Tambor con Miel', 'unidad': 'Uni'},
        {'codigo': 'TRR', 'descripcion': 'Tambor Reacondicionado Raldas', 'unidad': 'Uni'},
        {'codigo': 'TRC', 'descripcion': 'Tambor Reacondicionado Cosde', 'unidad': 'Uni'},
        {'codigo': 'TRO', 'descripcion': 'Tambor Reacondicionado Ombu', 'unidad': 'Uni'},
        {'codigo': 'TNAR', 'descripcion': 'Tambor Nuevo Alto Raldas', 'unidad': 'Uni'},
        {'codigo': 'TNAF', 'descripcion': 'Tambor Nuevo Alto Fabritam', 'unidad': 'Uni'},
        {'codigo': 'TNP', 'descripcion': 'Tambor Nuevo Petiso', 'unidad': 'Uni'},
        {'codigo': 'CO', 'descripcion': 'Cera Operculo', 'unidad': 'Kg'},
        {'codigo': 'CR', 'descripcion': 'Cera Recupero', 'unidad': 'Kg'},
      ];
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nueva Solicitud', style: DesignTokens.headlineStyle().copyWith(fontSize: 20)),
              const SizedBox(height: 8),
              Text('Para: ${apicultor['nombre']} - ${apicultor['localidad'] ?? 'S/D'}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              
              const Text('Tipo de Operación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Recolección')),
                      selected: selectedTipo == 'Recolección',
                      onSelected: (val) => setModalState(() => selectedTipo = 'Recolección'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Distribución')),
                      selected: selectedTipo == 'Distribución',
                      onSelected: (val) => setModalState(() => selectedTipo = 'Distribución'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text('Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) {
                      String searchQuery = '';
                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          final filteredProds = productos.where((p) => 
                            (p['codigo']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false) || 
                            (p['descripcion']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false)
                          ).toList();
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
                                        title: Text(filteredProds[i]['codigo'] ?? ''),
                                        subtitle: Text(filteredProds[i]['descripcion'] ?? ''),
                                        trailing: Text(filteredProds[i]['unidad'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                        onTap: () => Navigator.pop(context, filteredProds[i]['codigo']),
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
                    color: DesignTokens.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 20, color: DesignTokens.primary.withOpacity(0.5)),
                      const SizedBox(width: 12),
                      Text(selectedProducto ?? 'Seleccionar producto...', 
                        style: TextStyle(color: selectedProducto != null ? DesignTokens.primary : Colors.black38)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Cantidad Estimada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: cantidadController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Ej: 15',
                  filled: true,
                  fillColor: DesignTokens.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedProducto == null || cantidadController.text.isEmpty) return;
                    
                    try {
                      final service = SupabaseService();
                      await service.createNecesidad({
                        'solicitud_codigo': 'SOL-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                        'apicultor_id': apicultor['apicultor_codigo'] ?? apicultor['id'],
                        'producto': selectedProducto,
                        'cantidad': double.tryParse(cantidadController.text) ?? 0,
                        'tipo': selectedTipo,
                        'localidad': apicultor['localidad'],
                        'estado': 'Pendiente',
                      });
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        _fetchDetailedData();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud guardada con éxito'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  style: DesignTokens.primaryButtonStyle,
                  child: const Text('GUARDAR SOLICITUD'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> a) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: DesignTokens.secondary.withOpacity(0.2), width: 1.5)),
              child: const CircleAvatar(radius: 54, backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=1974&auto=format&fit=crop')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: const Text('Apicultor', style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.5)),
        ),
        const SizedBox(height: 12),
        Text(a['nombre'] ?? 'Sin Nombre', textAlign: TextAlign.center, style: DesignTokens.headlineStyle().copyWith(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: DesignTokens.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: DesignTokens.primary.withOpacity(0.05))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cod', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: DesignTokens.primary.withOpacity(0.4))),
              const SizedBox(width: 6),
              Text(a['apicultor_codigo'] ?? a['id']?.toString().substring(0, 8) ?? 'S/C', style: const TextStyle(fontWeight: FontWeight.w900, color: DesignTokens.secondary, fontSize: 16, letterSpacing: 0.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditProfileButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
        label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.white)),
        style: DesignTokens.primaryButtonStyle,
      ),
    );
  }

  Widget _buildInfoGrid(Map<String, dynamic> a) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      children: [
        _buildInfoItem('DNI', a['dni']?.toString() ?? 'S/D'),
        _buildInfoItem('CUIT', a['cuit']?.toString() ?? 'S/D'),
        _buildInfoItem('RENAPA', a['renapa'] ?? 'S/D', highlight: true),
        _buildInfoItem('TELÉFONO', a['telefono'] ?? 'S/D'),
        _buildInfoItem('LOCALIDAD', a['localidad'] ?? 'S/D'),
      ],
    );
  }



  Widget _buildInfoItem(String label, String value, {bool highlight = false}) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 60) / 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DesignTokens.labelStyle().copyWith(fontSize: 8, color: Colors.black38)),
          const SizedBox(height: 4),
          Text(value, 
            style: DesignTokens.bodyStyle().copyWith(
              fontWeight: FontWeight.bold, 
              fontSize: 13,
              color: highlight ? DesignTokens.secondary : const Color(0xFF424846)
            )
          ),
        ],
      ),
    );
  }

  Widget _buildPendienteCard(Map<String, dynamic> s) {
    final tipo = s['tipo'] ?? 'Operación';
    final isRecoleccion = tipo.toLowerCase().contains('recolección');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.secondary.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isRecoleccion ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isRecoleccion ? Icons.download_rounded : Icons.upload_rounded,
              color: isRecoleccion ? const Color(0xFF1A6B43) : const Color(0xFFC68E17),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['producto'] ?? 'Producto', style: DesignTokens.bodyStyle().copyWith(fontWeight: FontWeight.bold)),
                Text('${tipo} • Estimado: ${s['cantidad']} kg', 
                  style: DesignTokens.bodyStyle().copyWith(fontSize: 12, color: Colors.black38)
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: DesignTokens.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(s['estado']?.toUpperCase() ?? 'PENDIENTE', 
              style: DesignTokens.labelStyle().copyWith(fontSize: 8, color: DesignTokens.secondary, fontWeight: FontWeight.w900)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSummary() {
    if (_resumenDetallado.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('No hay operaciones finalizadas')),
      );
    }

    return Column(
      children: _resumenDetallado.entries.map((e) => _buildProductCardDetailed(e.key, e.value)).toList(),
    );
  }

  Widget _buildProductCardDetailed(String product, Map<String, double> totalsByType) {
    double total = totalsByType.values.fold(0, (sum, v) => sum + v);
    IconData icon = Icons.hive_rounded;
    Color iconColor = const Color(0xFFC68E17);
    
    if (product.toLowerCase().contains('tambor')) icon = Icons.inventory_2_rounded;
    else if (product.toLowerCase().contains('alimento')) icon = Icons.eco_rounded;
    else if (product.toLowerCase().contains('cera')) icon = Icons.layers_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFDF7E7), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              Row(
                children: totalsByType.entries.map((t) => Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(t.key.toUpperCase(), style: DesignTokens.labelStyle().copyWith(fontSize: 7, color: Colors.black38)),
                      Text('${NumberFormat('#,###', 'es_AR').format(t.value)} kg', 
                        style: DesignTokens.bodyStyle().copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF424846))
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(product.toUpperCase(), style: DesignTokens.labelStyle().copyWith(fontSize: 8, color: Colors.black38)),
          const SizedBox(height: 4),
          Text('TOTAL: ${NumberFormat('#,###', 'es_AR').format(total)} kg', 
            style: DesignTokens.headlineStyle().copyWith(fontSize: 20, fontWeight: FontWeight.w400, color: const Color(0xFF424846))
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total / _maxTotal,
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHistoryTable() {
    if (_historial.isEmpty) {
       return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('No hay historial de remitos')),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E302C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _buildTableHeader('FECHA', 2),
                _buildTableHeader('TIPO DE OPERACIÓN', 3),
                _buildTableHeader('PRODUCTO', 3),
                _buildTableHeader('CANT.', 2, alignRight: true),
              ],
            ),
          ),
          ..._historial.map((op) => _buildHistoryRow(op)).toList(),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, int flex, {bool alignRight = false}) {
    return Expanded(
      flex: flex,
      child: Text(text, 
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: DesignTokens.labelStyle().copyWith(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5)
      ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> op) {
    final dateStr = op['fecha'] != null 
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(op['fecha']))
        : '--/--/----';
    
    final tipo = op['tipo'] ?? 'Entrega';
    final isEntrega = tipo.toLowerCase().contains('entrega') || tipo.toLowerCase().contains('recolección');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(dateStr, style: DesignTokens.bodyStyle().copyWith(fontSize: 10, color: Colors.black54))),
          Expanded(flex: 3, child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEntrega ? const Color(0xFF1A6B43) : const Color(0xFFC68E17),
                ),
              ),
              const SizedBox(width: 8),
              Text(tipo, style: DesignTokens.bodyStyle().copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF424846))),
            ],
          )),
          Expanded(flex: 3, child: Text(op['producto'] ?? 'S/D', 
            style: DesignTokens.bodyStyle().copyWith(fontSize: 11, color: Colors.black54),
            overflow: TextOverflow.ellipsis,
          )),
          Expanded(flex: 2, child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${NumberFormat('#,###', 'es_AR').format(op['cantidad'] ?? 0)}', 
                style: DesignTokens.bodyStyle().copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF424846))
              ),
              Text(op['unidad'] ?? 'kg', style: DesignTokens.bodyStyle().copyWith(fontSize: 10, color: Colors.black38)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? actionText, {bool showIcons = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(showIcons ? Icons.history_rounded : Icons.analytics_outlined, color: DesignTokens.secondary, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(title, 
                  overflow: TextOverflow.ellipsis,
                  style: DesignTokens.headlineStyle().copyWith(fontSize: 18, fontWeight: FontWeight.w400, color: const Color(0xFF424846))
                ),
              ),
            ],
          ),
        ),
        if (actionText != null)
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generando informe detallado del apicultor...'), duration: Duration(seconds: 2))
              );
            },
            child: Text(actionText, style: DesignTokens.labelStyle().copyWith(color: DesignTokens.secondary, fontWeight: FontWeight.w900, fontSize: 10)),
          ),
        if (showIcons)
          Row(
            children: [
              _buildSmallIconAction(Icons.filter_list_rounded),
              const SizedBox(width: 12),
              _buildSmallIconAction(Icons.file_download_outlined),
            ],
          ),
      ],
    );
  }

  Widget _buildSmallIconAction(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Icon(icon, size: 18, color: Colors.black38),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.local_shipping_outlined, 'FLEET'),
          _buildNavItem(Icons.location_on_outlined, 'DRIVERS', active: true),
          _buildNavItem(Icons.map_outlined, 'ROUTES'),
          _buildNavItem(Icons.notifications_none_rounded, 'ALERTS'),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, {bool active = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: active ? DesignTokens.secondary : Colors.black26, size: 24),
        const SizedBox(height: 4),
        Text(label, style: DesignTokens.labelStyle().copyWith(
          fontSize: 8, 
          fontWeight: FontWeight.w900,
          color: active ? DesignTokens.secondary : Colors.black26
        )),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          const Icon(Icons.assignment_outlined, size: 32, color: Colors.black12),
          const SizedBox(height: 12),
          Text('No hay solicitudes pendientes', style: DesignTokens.bodyStyle().copyWith(color: Colors.black26, fontSize: 13)),
        ],
      ),
    );
  }
}
