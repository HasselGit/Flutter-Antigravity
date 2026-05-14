import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/design_tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../backend/supabase_service.dart';
import '../backend/apicultores_data.dart';
import '../backend/app_states.dart';

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
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _refreshApicultorData();
    _fetchDetailedData();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userRole = prefs.getString('user_puesto'));
  }

  Future<void> _refreshApicultorData() async {
    try {
      final code = widget.apicultor['apicultor_codigo'] ?? widget.apicultor['id'];
      if (code == null) return;
      
      // 1. Obtener datos del fallback local (Nuestra fuente de verdad para estos campos)
      final localData = ApicultoresData.fallbackApicultores.firstWhere(
        (a) => a['apicultor_codigo'] == code,
        orElse: () => {},
      );

      // 2. Obtener datos de la DB
      final fullData = await Supabase.instance.client
          .from('apicultores')
          .select('id, nombre, localidad, provincia, cuit, telefono, renapa')
          .eq('id', code)
          .maybeSingle();

      if (mounted) {
        setState(() {
          // Estrategia de mezcla: 
          // 1. Empezamos con lo que ya tenemos
          // 2. Aplicamos fallback local (prioridad alta para integridad)
          if (localData.isNotEmpty) {
            widget.apicultor.addAll(localData);
          }
          
          // 3. Aplicamos DB solo si los campos no están vacíos y parecen correctos
          if (fullData != null) {
            fullData.forEach((key, value) {
              if (value != null && value.toString().isNotEmpty) {
                // Validación especial para evitar swaps de nombre/localidad detectados
                if (key == 'localidad' && value.toString().contains(',') && localData['localidad'] != null) {
                   // Si la localidad de la DB tiene comas y la local no, sospechamos error de swap
                   return;
                }
                widget.apicultor[key] = value;
              }
            });
          }

          // 4. Si la DB no tiene datos críticos que sí están en el local, intentar subirlos (Sanitización)
          _syncToSupabaseIfNeeded(code, localData, fullData);
        });
      }
    } catch (e) {
      print('Error refreshing apicultor data: $e');
    }
  }

  Future<void> _syncToSupabaseIfNeeded(String id, Map<String, dynamic> local, Map<String, dynamic>? db) async {
    if (db == null) return;
    
    Map<String, dynamic> toUpdate = {};
    
    // Lista de campos críticos para integridad (dni es solo local por ahora)
    final fields = ['cuit', 'renapa', 'localidad', 'provincia', 'telefono'];
    
    for (var f in fields) {
      final localVal = local[f]?.toString() ?? '';
      final dbVal = db[f]?.toString() ?? '';
      
      if (localVal.isNotEmpty && dbVal.isEmpty) {
        toUpdate[f] = localVal;
      }
    }

    // Caso especial: Nombre mal cargado o truncado en DB
    final localName = local['nombre']?.toString() ?? '';
    final dbName = db['nombre']?.toString() ?? '';
    if (localName.isNotEmpty && localName.length > dbName.length + 5 && localName.contains(dbName)) {
      toUpdate['nombre'] = localName;
    }

    if (toUpdate.isNotEmpty) {
      print('DEBUG: Sincronizando datos faltantes a Supabase para $id: $toUpdate');
      await SupabaseService().updateApicultorBasicData(id, toUpdate);
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

      // 1. Fetch Solicitudes (Filtradas por ID desde la DB)
      final allSolsRes = await client.from('solicitudes')
          .select('*')
          .or('apicultor_id.eq.$apiId,apicultor_id.eq.$alternateId');
      
      final List<Map<String, dynamic>> pendientes = List<Map<String, dynamic>>.from(allSolsRes).where((s) {
        final estado = (s['estado'] ?? 'Pendiente').toString().toLowerCase();
        return estado == 'pendiente' || estado == 'solicitado' || estado == 'asignada' || estado == 'en curso';
      }).toList();

      _debugInfo = '';
      
      // 2. Fetch completed operations through Paradas
      // paradas -> solicitudes -> apicultor_id
      // Joining remitos and parada_items for full history
      final paradasRes = await client
          .from('paradas')
          .select('*, remitos(remito_codigo, created_at), parada_items(producto_codigo, cantidad, unidad), solicitudes!inner(apicultor_id)')
          .or('solicitudes.apicultor_id.eq.$apiId,solicitudes.apicultor_id.eq.$alternateId')
          .not('remito_id', 'is', null)
          .order('created_at', { 'ascending': false });
      
      final List<Map<String, dynamic>> apiParadas = List<Map<String, dynamic>>.from(paradasRes as List);
      
      // 4. Process Historial and Resumen
      List<Map<String, dynamic>> historial = [];
      Map<String, Map<String, double>> resumen = {};
      double maxT = 0;

      // Incluir solicitudes pendientes en el resumen
      for (var s in pendientes) {
        final prod = s['producto'] ?? 'S/D';
        final cant = double.tryParse(s['cantidad']?.toString() ?? '0') ?? 0;
        final tipo = s['tipo'] ?? 'Operación';
        
        resumen.putIfAbsent(prod, () => {});
        resumen[prod]![tipo] = (resumen[prod]![tipo] ?? 0) + cant;
      }

      for (var p in apiParadas) {
        final rem = p['remitos'] ?? {};
        final items = List<Map<String, dynamic>>.from(p['parada_items'] ?? []);
        final tipo = p['tipo'] ?? 'Operación';
        
        for (var item in items) {
          final prod = item['producto_codigo'] ?? 'S/D';
          final cant = double.tryParse(item['cantidad']?.toString() ?? '0') ?? 0;
          
          historial.add({
            'fecha': rem['created_at'] ?? p['created_at'],
            'tipo': tipo,
            'producto': prod,
            'cantidad': cant,
            'unidad': item['unidad'] ?? 'kg',
            'remito': rem['remito_codigo'],
          });

          resumen.putIfAbsent(prod, () => {});
          resumen[prod]![tipo] = (resumen[prod]![tipo] ?? 0) + cant;
        }
      }

      // Calcular maxTotal para barras de progreso
      for (var prodResumen in resumen.values) {
        double prodTotal = prodResumen.values.fold(0.0, (a, b) => a + b);
        if (prodTotal > maxT) maxT = prodTotal;
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
    if (_userRole == 'Chofer') {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Restringido')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_rounded, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('No tiene permisos para ver perfiles de apicultores', 
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => context.pop(), child: const Text('VOLVER'))
            ],
          ),
        ),
      );
    }

    final a = widget.apicultor;
    return Scaffold(
      backgroundColor: DesignTokens.surface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
            onPressed: () => context.pop(),
          ),
          centerTitle: false,
          title: Text('Perfil de Apicultor', 
            style: DesignTokens.headlineStyle().copyWith(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: DesignTokens.primary)
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
                  _buildInfoGrid(a),
                  
                  const SizedBox(height: 40),
                  _buildSectionHeader('Operaciones Pendientes', null),
                  const SizedBox(height: 16),
                  if (_pendientes.isEmpty)
                    _buildEmptyState()
                  else
                    ..._pendientes.map((s) => _buildPendienteCard(s)).toList(),

                  // Sección: Resumen de Operaciones (Totales por Producto y Tipo)
                  if (_resumenDetallado.isNotEmpty) ...[
                    const SizedBox(height: 40),
                    _buildSectionHeader('Resumen de Operaciones', 'VER INFORME COMPLETO'),
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
      floatingActionButton: (_userRole == 'CEO' || _userRole == 'Gerente' || _userRole == 'Compras') 
        ? FloatingActionButton(
            onPressed: _showAddSolicitudModal,
            backgroundColor: DesignTokens.secondary,
            elevation: 8,
            child: const Icon(Icons.add_rounded, color: DesignTokens.primary, size: 32),
          )
        : null,
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
      builder: (context) {
        bool _savingSolicitud = false;
        return StatefulBuilder(
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
                    onPressed: _savingSolicitud ? null : () async {
                      if (selectedProducto == null || cantidadController.text.isEmpty) return;
                      
                      setModalState(() => _savingSolicitud = true);
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
                      } finally {
                        if (context.mounted) setModalState(() => _savingSolicitud = false);
                      }
                    },
                    style: DesignTokens.primaryButtonStyle,
                    child: _savingSolicitud 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('GUARDAR SOLICITUD'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> a) {
    return Column(
      children: [
        const SizedBox(height: 10),
        
        // Name
        Text(
          a['nombre'] ?? 'Sin Nombre',
          textAlign: TextAlign.center,
          style: DesignTokens.headlineStyle().copyWith(
            fontSize: 24, 
            fontWeight: FontWeight.w900, 
            color: DesignTokens.primary,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 14),
        
        // COD box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: DesignTokens.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('CÓDIGO DE APICULTOR:', style: DesignTokens.labelStyle().copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: DesignTokens.primary.withOpacity(0.5))),
              const SizedBox(width: 8),
              Text(
                a['apicultor_codigo'] ?? a['id'] ?? 'S/C',
                style: TextStyle(fontWeight: FontWeight.w900, color: DesignTokens.primary, fontSize: 16, letterSpacing: 1.0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEditProfileButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
        label: const Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
        style: DesignTokens.secondaryButtonStyle.copyWith(
          backgroundColor: WidgetStateProperty.all(DesignTokens.primary),
        ),
      ),
    );
  }

  Widget _buildInfoGrid(Map<String, dynamic> a) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.outline.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildInfoItem('DNI', a['dni']?.toString() ?? a['documento']?.toString() ?? '—')),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoItem('CUIT', a['cuit']?.toString() ?? '—')),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: DesignTokens.outline.withOpacity(0.05), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoItem('RENAPA', a['renapa'] ?? '—', highlight: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoItem('TELÉFONO', a['telefono'] ?? '—')),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: DesignTokens.outline.withOpacity(0.05), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoItem('LOCALIDAD', a['localidad'] ?? '—', highlight: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoItem('PROVINCIA', a['provincia'] ?? '—')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DesignTokens.labelStyle().copyWith(fontSize: 9, color: DesignTokens.onSurfaceVariant.withOpacity(0.5))),
        const SizedBox(height: 4),
        Text(
          value,
          style: DesignTokens.bodyStyle().copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: highlight ? DesignTokens.secondary : DesignTokens.primary,
          ),
        ),
      ],
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
              color: isRecoleccion ? DesignTokens.success.withOpacity(0.1) : DesignTokens.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isRecoleccion ? Icons.download_rounded : Icons.upload_rounded,
              color: isRecoleccion ? DesignTokens.success : DesignTokens.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['producto'] ?? 'Producto', style: DesignTokens.bodyStyle().copyWith(fontWeight: FontWeight.bold)),
                Text('${tipo} • Estimado: ${s['cantidad']} ${s['unidad'] ?? 'kg'}', 
                  style: DesignTokens.bodyStyle().copyWith(fontSize: 12, color: Colors.black38)
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(s['estado']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(s['estado']?.toUpperCase() ?? 'PENDIENTE', 
              style: DesignTokens.labelStyle().copyWith(fontSize: 8, color: _getStatusColor(s['estado']), fontWeight: FontWeight.w900)
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(dynamic estado) {
    final e = estado?.toString().toLowerCase() ?? '';
    if (e.contains('pendiente')) return DesignTokens.secondary;
    if (e.contains('asignada')) return Colors.blue;
    if (e.contains('en curso')) return Colors.orange;
    if (e.contains('terminada') || e.contains('finalizada')) return DesignTokens.success;
    return DesignTokens.secondary;
  }

  Widget _buildProductSummary() {
    return Column(
      children: _resumenDetallado.entries.map((entry) {
        final product = entry.key;
        final totalsByType = entry.value;
        return _buildProductCardDetailed(product, totalsByType);
      }).toList(),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.outline.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              // Totales por tipo en chips compactos
              Row(
                children: totalsByType.entries.map((t) => Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.key.toLowerCase().contains('recolección') || t.key.toLowerCase().contains('entrega') 
                        ? DesignTokens.success.withOpacity(0.1) 
                        : DesignTokens.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${t.key}: ${NumberFormat('#,###', 'es_AR').format(t.value)}',
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: t.key.toLowerCase().contains('recolección') || t.key.toLowerCase().contains('entrega') 
                          ? DesignTokens.success 
                          : DesignTokens.secondary
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(product.toUpperCase(), style: DesignTokens.labelStyle().copyWith(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(NumberFormat('#,###', 'es_AR').format(total), 
                style: DesignTokens.headlineStyle().copyWith(fontSize: 28, fontWeight: FontWeight.w900, color: DesignTokens.primary)
              ),
              const SizedBox(width: 8),
              Text('kg totales', style: DesignTokens.bodyStyle().copyWith(fontSize: 14, color: Colors.black26)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total / _maxTotal,
              backgroundColor: DesignTokens.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              minHeight: 6,
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
          _buildNavItem(Icons.home_filled, 'HOME', onTap: () => context.go('/home')),
          _buildNavItem(Icons.assignment_rounded, 'OPERAR', onTap: () => context.go('/rutas')),
          _buildNavItem(Icons.analytics_rounded, 'MÉTRICAS', onTap: () => context.go('/gerenteHome')),
          _buildNavItem(Icons.person_rounded, 'MI PERFIL', active: true),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, {bool active = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
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
      ),
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
