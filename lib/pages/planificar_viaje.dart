import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PlanificarViajeWidget extends StatefulWidget {
  const PlanificarViajeWidget({super.key});

  static String routeName = 'PlanificarViaje';
  static String routePath = '/planificarViaje';

  @override
  State<PlanificarViajeWidget> createState() => _PlanificarViajeWidgetState();
}

class _PlanificarViajeWidgetState extends State<PlanificarViajeWidget> {
  final _formKey = GlobalKey<FormState>();
  final _choferController = TextEditingController();
  final _vehiculoController = TextEditingController();
  final _descripcionController = TextEditingController();
  DateTime _fechaPlanificada = DateTime.now();
  bool _isLoading = false;

  Future<void> _crearViaje() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('viajes').insert({
        'chofer_id': _choferController.text.trim(),
        'vehiculo_codigo': _vehiculoController.text.trim(),
        'viaje_codigo': _descripcionController.text.trim().isNotEmpty ? _descripcionController.text.trim() : 'VIAJE-NUEVO',
        'estado': 'Planificado',
        'fecha': _fechaPlanificada.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viaje planificado exitosamente', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaPlanificada,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF08201A)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _fechaPlanificada = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F8),
        elevation: 0,
        title: const Text('Planificar Nuevo Viaje', style: TextStyle(color: Color(0xFF08201A), fontWeight: FontWeight.bold, fontFamily: 'Manrope')),
        iconTheme: const IconThemeData(color: Color(0xFF08201A)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detalles Operativos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF08201A))),
                const SizedBox(height: 16),
                _buildField('Chofer Asignado (Nombre o ID)', Icons.person_rounded, _choferController),
                const SizedBox(height: 16),
                _buildField('Vehículo / Patente', Icons.local_shipping_rounded, _vehiculoController),
                const SizedBox(height: 16),
                _buildField('Descripción o Notas', Icons.notes_rounded, _descripcionController, maxLines: 3, required: false),
                const SizedBox(height: 24),
                
                const Text('Fecha Programada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF08201A))),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _seleccionarFecha,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: Color(0xFF08201A)),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('EEEE, d MMMM yyyy').format(_fechaPlanificada),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _crearViaje,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDBE49), // kSecContainer
                      foregroundColor: const Color(0xFF08201A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF08201A), strokeWidth: 3))
                        : const Text('CREAR VIAJE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Work Sans', letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, IconData icon, TextEditingController controller, {int maxLines = 1, bool required = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: required ? (v) => v == null || v.isEmpty ? 'Campo requerido' : null : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF08201A).withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFF08201A).withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFF08201A).withOpacity(0.1)),
        ),
      ),
    );
  }
}
