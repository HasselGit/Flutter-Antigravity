import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/design_tokens.dart';

class ProductosPageWidget extends StatefulWidget {
  const ProductosPageWidget({super.key});

  @override
  State<ProductosPageWidget> createState() => _ProductosPageWidgetState();
}

class _ProductosPageWidgetState extends State<ProductosPageWidget> {
  List<Map<String, dynamic>> _productos = [];
  bool _loading = true;



  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client.from('productos')
          .select('id, descripcion, codigo, unidad')
          .order('descripcion', ascending: true);
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);
      
      // Ordenamiento manual adicional para garantizar A-Z en el cliente
      data.sort((a, b) => (a['descripcion'] ?? '').toString().toLowerCase()
          .compareTo((b['descripcion'] ?? '').toString().toLowerCase()));
      
      if (mounted) {
        setState(() {
          _productos = data;
          _loading = false;
        });
      }
    } catch (e) {
      // print('Error fetching productos: $e');
      if (mounted) setState(() => _loading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        title: const Text('Inventario de Productos', style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DesignTokens.primary), onPressed: () => context.pop()),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _productos.length,
            itemBuilder: (context, index) => _buildProductCard(_productos[index]),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        backgroundColor: DesignTokens.secondary,
        child: const Icon(Icons.add, color: DesignTokens.primary),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.inventory_2_rounded, color: DesignTokens.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['descripcion'] ?? 'Sin descripción', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Row(
                  children: [
                    Text('Código: ${p['codigo'] ?? 'S/C'}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                    const SizedBox(width: 10),
                    if (p['nombre'] != null) 
                      Text('• ${p['nombre']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Text(p['unidad'] ?? 'UN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: DesignTokens.primary)),
          ),
        ],
      ),
    );
  }

  void _addProduct() {
    final descController = TextEditingController();
    final codeController = TextEditingController();
    final acronymController = TextEditingController();
    String? selectedUnidad = 'Uni';

    final List<Map<String, dynamic>> predefinedProducts = [
      {'codigo': '1', 'nombre': 'TCM', 'descripcion': 'Tambor con Miel', 'unidad': 'Uni'},
      {'codigo': '2', 'nombre': 'TRR', 'descripcion': 'Tambor Reacondicionado Raldas', 'unidad': 'Uni'},
      {'codigo': '3', 'nombre': 'TRC', 'descripcion': 'Tambor Reacondicionado Cosde', 'unidad': 'Uni'},
      {'codigo': '4', 'nombre': 'TRO', 'descripcion': 'Tambor Reacondicionado Ombu', 'unidad': 'Uni'},
      {'codigo': '5', 'nombre': 'TNAR', 'descripcion': 'Tambor Nuevo Alto Raldas', 'unidad': 'Uni'},
      {'codigo': '6', 'nombre': 'TNAF', 'descripcion': 'Tambor Nuevo Alto Fabritam', 'unidad': 'Uni'},
      {'codigo': '7', 'nombre': 'TNP', 'descripcion': 'Tambor Nuevo Petiso', 'unidad': 'Uni'},
      {'codigo': '8', 'nombre': 'CO', 'descripcion': 'Cera Operculo', 'unidad': 'Kg'},
      {'codigo': '9', 'nombre': 'CR', 'descripcion': 'Cera Recupero', 'unidad': 'Kg'},
      {'codigo': '10', 'nombre': 'CE STD', 'descripcion': 'Cera Estampada STD', 'unidad': 'Uni'},
      {'codigo': '11', 'nombre': 'CE 3/4', 'descripcion': 'Cera Estampada 3/4', 'unidad': 'Uni'},
      {'codigo': '13', 'nombre': 'TE', 'descripcion': 'Techo Calden', 'unidad': 'Uni'},
      {'codigo': '14', 'nombre': 'PI', 'descripcion': 'Piso Calden', 'unidad': 'Uni'},
      {'codigo': '15', 'nombre': 'AL1 STD', 'descripcion': 'Alzas de Primera STD', 'unidad': 'Uni'},
      {'codigo': '16', 'nombre': 'AL2 STD', 'descripcion': 'Alzas de Segunda STD', 'unidad': 'Uni'},
      {'codigo': '19', 'nombre': 'TV', 'descripcion': 'Tabla de Varroa', 'unidad': 'Caja x 600 Uni'},
      {'codigo': '20', 'nombre': 'AZ', 'descripcion': 'Azucar', 'unidad': 'Bolsa x 50 Kg'},
      {'codigo': '21', 'nombre': 'GL', 'descripcion': 'Glucosa', 'unidad': 'Kg'},
      {'codigo': '22', 'nombre': 'TRM S/B', 'descripcion': 'Tambor Reacondicionado Myhura S/B', 'unidad': 'Uni'},
      {'codigo': '23', 'nombre': 'TRM C/B', 'descripcion': 'Tambor Reacondicionado Myhura C/B', 'unidad': 'Uni'},
      {'codigo': '17', 'nombre': 'AL1 3/4', 'descripcion': 'Alzas de Primera 3/4', 'unidad': 'Uni'},
      {'codigo': '18', 'nombre': 'AL2 3/4', 'descripcion': 'Alzas de Segunda 3/4', 'unidad': 'Uni'},
      {'codigo': '24', 'nombre': 'LA', 'descripcion': 'Largueros', 'unidad': 'Uni'},
      {'codigo': '12', 'nombre': 'NU', 'descripcion': 'Nucleros', 'unidad': 'Uni'},
      {'codigo': '25', 'nombre': 'CU', 'descripcion': 'Cuadros', 'unidad': 'Uni'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nuevo Producto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
              const SizedBox(height: 20),
              DropdownButtonFormField<Map<String, dynamic>>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Seleccionar de Lista Oficial', prefixIcon: Icon(Icons.list_alt_rounded)),
                items: predefinedProducts.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text('${p['nombre']} - ${p['descripcion']}', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (p) {
                  if (p != null) {
                    setModalState(() {
                      acronymController.text = p['nombre'] ?? '';
                      descController.text = p['descripcion'] ?? '';
                      codeController.text = p['codigo'] ?? '';
                      selectedUnidad = p['unidad'] ?? 'Uni';
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              TextField(
                controller: acronymController,
                decoration: const InputDecoration(labelText: 'Producto (Siglas)', prefixIcon: Icon(Icons.label_rounded)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Descripción Completa', prefixIcon: Icon(Icons.inventory_2_outlined)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Código Numérico', prefixIcon: Icon(Icons.qr_code_rounded)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedUnidad,
                decoration: const InputDecoration(labelText: 'Unidad de Medida'),
                items: ['Uni', 'Kg', 'L', 'Bolsa x 50 Kg', 'Caja x 600 Uni']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setModalState(() => selectedUnidad = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (descController.text.isEmpty) return;
                    try {
                      // Al parecer la columna 'nombre' no existe en la tabla 'productos'.
                      // Usaremos 'codigo' para almacenar las siglas y 'descripcion' para el nombre completo.
                      // Usamos upsert para evitar errores de duplicación si el producto ya existe.
                      await Supabase.instance.client.from('productos').upsert({
                        'descripcion': descController.text,
                        'codigo': acronymController.text.isNotEmpty ? acronymController.text : codeController.text,
                        'unidad': selectedUnidad,
                      }, onConflict: 'codigo');
                      Navigator.pop(ctx);
                      _fetchData();
                    } catch (e) {
                      if (mounted) {
                        Navigator.pop(context);
                        String errorMsg = e.toString();
                        if (errorMsg.contains('p.rol')) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Error de Base de Datos (RLS)'),
                              content: const Text(
                                'Se detectó que una política de seguridad en Supabase intenta usar la columna "rol" que no existe.\n\n'
                                'Por favor, ejecute este SQL en su panel de Supabase para solucionarlo:\n\n'
                                'ALTER TABLE profiles ADD COLUMN IF NOT EXISTS rol TEXT;\n'
                                'UPDATE profiles SET rol = puesto WHERE rol IS NULL;'
                              ),
                              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
                        }
                      }
                    }
                  },
                  style: DesignTokens.primaryButtonStyle,
                  child: const Text('GUARDAR PRODUCTO'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
