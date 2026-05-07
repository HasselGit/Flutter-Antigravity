import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../backend/design_tokens.dart';

class RemitoPageWidget extends StatefulWidget {
  final String paradaId;
  final String? receptorTipo;
  final String? receptorNombre;
  final String? receptorDni;

  const RemitoPageWidget({
    super.key, 
    required this.paradaId,
    this.receptorTipo,
    this.receptorNombre,
    this.receptorDni,
  });

  static String routeName = 'RemitoPage';
  static String routePath = '/remito';

  @override
  State<RemitoPageWidget> createState() => _RemitoPageWidgetState();
}

class _RemitoPageWidgetState extends State<RemitoPageWidget> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _paradaData;
  Map<String, dynamic>? _viajeData;
  List<Map<String, dynamic>> _items = [];

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final parada = await Supabase.instance.client
          .from('paradas')
          .select('id, viaje_id, orden_secuencia, tipo, ubicacion, localidad, estado, bruto_kg, neto_kg')
          .eq('id', widget.paradaId)
          .maybeSingle();

      if (parada == null) throw Exception('Parada no encontrada');

      final itemsRaw = await Supabase.instance.client
          .from('parada_items')
          .select('id, producto_codigo, cantidad, unidad, peso_kg')
          .eq('parada_id', widget.paradaId);
      
      _paradaData = parada;
      _items = List<Map<String, dynamic>>.from(itemsRaw);

      final viajeId = parada['viaje_id'];
      if (viajeId != null) {
        final viaje = await Supabase.instance.client
            .from('viajes')
            .select('id, viaje_codigo, vehiculo_codigo, chofer_id')
            .eq('id', viajeId)
            .maybeSingle();
        _viajeData = viaje;
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _shareWhatsApp(String pdfUrl) async {
    final String text = 'Hola, le envío el Remito Digital de la operación: $pdfUrl';
    final String url = 'https://wa.me/?text=${Uri.encodeComponent(text)}';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
    }
  }

  Future<void> _generarYCompartirPDF() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, firme el remito antes de generarlo.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes == null) throw Exception('Error al procesar firma');

      final pdf = pw.Document();

      double tryParseDouble(dynamic val) {
        if (val == null) return 0.0;
        if (val is num) return val.toDouble();
        return double.tryParse(val.toString()) ?? 0.0;
      }

      final tipoOperacion = _paradaData?['tipo'] ?? 'Operación';
      final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      final apicultorNombre = _paradaData?['ubicacion'] ?? 'Sin nombre';
      final receptorNombre = widget.receptorTipo == 'Tercero' ? widget.receptorNombre : apicultorNombre;
      final receptorDni = widget.receptorTipo == 'Tercero' ? widget.receptorDni : '';

      double totalBruto = tryParseDouble(_paradaData?['bruto_kg']);
      double totalNeto = tryParseDouble(_paradaData?['neto_kg']);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('REMITO DIGITAL', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('GeoLogística', style: pw.TextStyle(fontSize: 18, color: PdfColors.green900)),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Text('ID Parada: ${widget.paradaId.split('-').first.toUpperCase()}', style: pw.TextStyle(color: PdfColors.grey700)),
                pw.Text('Fecha: $fecha', style: pw.TextStyle(color: PdfColors.grey700)),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 15),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Vehículo: ${_viajeData?['vehiculo_codigo'] ?? 'S/D'}'),
                        pw.Text('Operación: $tipoOperacion'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Ubicación: ${_paradaData?['ubicacion'] ?? 'S/D'}'),
                        pw.Text('Localidad: ${_paradaData?['localidad'] ?? 'S/D'}'),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text('Responsable: $receptorNombre', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                if (receptorDni != null && receptorDni.isNotEmpty) pw.Text('DNI/CUIT: $receptorDni'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ['Producto', 'Cant', 'Unidad', 'Peso'],
                  data: _items.map((item) => [
                    item['producto_codigo'] ?? '-',
                    item['cantidad']?.toString() ?? '0',
                    item['unidad'] ?? '-',
                    item['peso_kg']?.toString() ?? '0.0'
                  ]).toList(),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
                  headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                if (totalBruto > 0) pw.Text('Total Bruto: ${totalBruto.toStringAsFixed(2)} KG'),
                if (totalNeto > 0) pw.Text('Total Neto: ${totalNeto.toStringAsFixed(2)} KG'),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Column(
                      children: [
                        pw.Image(pw.MemoryImage(signatureBytes), width: 150),
                        pw.Container(width: 150, height: 1, color: PdfColors.black),
                        pw.Text('Firma del Responsable'),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName = 'remito_${widget.paradaId.split('-').first}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      await Supabase.instance.client.storage.from('remitos').uploadBinary(
        fileName, 
        pdfBytes,
        fileOptions: const FileOptions(contentType: 'application/pdf'),
      );
      final pdfUrl = Supabase.instance.client.storage.from('remitos').getPublicUrl(fileName);

      final humanId = 'REM-${widget.paradaId.split('-').first.toUpperCase()}';
      await Supabase.instance.client.from('remitos').insert({
        'parada_id': widget.paradaId,
        'pdf_url': pdfUrl,
        'remito_codigo': humanId,
        'estado': 'Emitido',
      });

      // Update parada status
      await Supabase.instance.client.from('paradas').update({'estado': 'Terminado'}).eq('id', widget.paradaId);

      if (mounted) {
        setState(() => _loading = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remito Emitido', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('El remito digital ha sido generado y guardado correctamente.'),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('COMPARTIR'),
                onPressed: () {
                  Navigator.pop(ctx);
                  Printing.sharePdf(bytes: pdfBytes, filename: 'Remito_$humanId.pdf');
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('WHATSAPP'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  _shareWhatsApp(pdfUrl);
                },
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CERRAR')),
            ],
          ),
        ).then((_) => context.pop());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: DesignTokens.primary)));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Error')), body: Center(child: Text(_error!)));

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        title: Text('Finalizar Operación', style: DesignTokens.headlineStyle().copyWith(fontSize: 17)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Firma de Conformidad', style: DesignTokens.headlineStyle().copyWith(fontSize: 22)),
            const SizedBox(height: 8),
            Text('El responsable debe firmar para validar la operación y generar el remito.', style: TextStyle(color: DesignTokens.onSurfaceVariant)),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Signature(
                  controller: _signatureController,
                  height: 300,
                  backgroundColor: const Color(0xFFF9F9F9),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _signatureController.clear(),
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.redAccent),
                label: const Text('Limpiar Firma', style: TextStyle(color: Colors.redAccent)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _generarYCompartirPDF,
                style: DesignTokens.primaryButtonStyle,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('FINALIZAR Y GENERAR REMITO'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
