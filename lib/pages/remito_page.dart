import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';

class RemitoPageWidget extends StatefulWidget {
  final String paradaId;
  const RemitoPageWidget({super.key, required this.paradaId});

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
          .select('*, parada_items(*)')
          .eq('id', widget.paradaId)
          .maybeSingle();

      if (parada == null) throw Exception('Parada no encontrada');

      _paradaData = parada;
      _items = List<Map<String, dynamic>>.from(parada['parada_items'] ?? []);

      final viajeId = parada['viaje_id'];
      if (viajeId != null) {
        final viaje = await Supabase.instance.client
            .from('viajes')
            .select('*')
            .eq('id', viajeId)
            .maybeSingle();
        _viajeData = viaje;
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _generarYCompartirPDF() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, firme el remito antes de generarlo.')));
      return;
    }

    final signatureBytes = await _signatureController.toPngBytes();
    if (signatureBytes == null) return;

    final pdf = pw.Document();

    // Convert string to double safely
    double tryParseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    // Datos del viaje
    final chofer = _viajeData?['chofer_asignado'] ?? 'No asignado';
    final vehiculo = _viajeData?['vehiculo_asignado'] ?? 'No asignado';
    final tipoOperacion = _paradaData?['tipo_operacion'] ?? 'Operación';
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    double totalBruto = tryParseDouble(_paradaData?['bruto_kg']);
    double totalNeto = tryParseDouble(_paradaData?['neto_kg']);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('REMITO DIGITAL', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('GeoLogística', style: pw.TextStyle(fontSize: 18, color: PdfColors.green800)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text('ID Parada: ${widget.paradaId.split('-').first.toUpperCase()}', style: pw.TextStyle(color: PdfColors.grey700)),
              pw.Text('Fecha de Emisión: $fecha', style: pw.TextStyle(color: PdfColors.grey700)),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 15),

              // Info Chofer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Chofer: $chofer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Vehículo: $vehiculo'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Operación: $tipoOperacion', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Destino: ${_paradaData?['direccion'] ?? 'Ubicación'}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('Detalle de Ítems', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              // Table
              pw.TableHelper.fromTextArray(
                headers: ['Producto', 'Cantidad (U)', 'Peso Unitario (KG)', 'Subtotal (KG)'],
                data: _items.map((item) {
                  final prod = item['producto'] ?? '-';
                  final qty = tryParseDouble(item['cantidad']);
                  final peso = tryParseDouble(item['peso_kg']);
                  return [prod, qty.toStringAsFixed(0), peso.toStringAsFixed(2), (qty * peso).toStringAsFixed(2)];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellAlignment: pw.Alignment.center,
              ),

              pw.SizedBox(height: 20),
              
              if (tipoOperacion == 'Recolección')
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Peso Bruto de Báscula: ${totalBruto.toStringAsFixed(2)} KG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      if (totalNeto > 0)
                        pw.Text('Peso Neto de Báscula: ${totalNeto.toStringAsFixed(2)} KG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ]
                  )
                ),

              pw.Spacer(),

              // Firmas
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(
                        height: 80,
                        width: 150,
                        child: pw.Image(pw.MemoryImage(signatureBytes)),
                      ),
                      pw.Container(width: 150, child: pw.Divider()),
                      pw.Text('Firma del Responsable', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 80), // Espacio en blanco para firmar luego
                      pw.Container(width: 150, child: pw.Divider()),
                      pw.Text('Firma del Chofer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
            ],
          );
        },
      ),
    );

    // Guardar el PDF generado
    final pdfBytes = await pdf.save();
    
    try {
      // 1. Subir a Supabase Storage (bucket 'remitos')
      final fileName = 'remito_${widget.paradaId.split('-').first}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await Supabase.instance.client.storage.from('remitos').uploadBinary(
        fileName, 
        pdfBytes,
        fileOptions: const FileOptions(contentType: 'application/pdf'),
      );
      final pdfUrl = Supabase.instance.client.storage.from('remitos').getPublicUrl(fileName);

      // 2. Crear registro en la tabla remitos
      final humanId = 'REM-${widget.paradaId.split('-').first.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      await Supabase.instance.client.from('remitos').insert({
        'parada_id': widget.paradaId,
        'pdf_url': pdfUrl,
        'human_id': humanId,
        'estado': 'Emitido',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remito guardado en la nube'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar en la nube: $e'), backgroundColor: Colors.orange));
      }
    }

    // 3. Compartir (WhatsApp, etc)
    await Printing.sharePdf(bytes: pdfBytes, filename: 'Remito_${widget.paradaId.split('-').first}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Error')), body: Center(child: Text(_error!)));

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F8),
        title: const Text('Generar Remito', style: TextStyle(color: Color(0xFF08201A), fontWeight: FontWeight.bold, fontFamily: 'Manrope')),
        iconTheme: const IconThemeData(color: Color(0xFF08201A)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Firma Digital',
              style: TextStyle(fontFamily: 'Manrope', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF08201A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Por favor, que el responsable de la entrega o recepción firme en el recuadro.',
              style: TextStyle(fontFamily: 'Inter', color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Signature(
                  controller: _signatureController,
                  height: 250,
                  backgroundColor: const Color(0xFFF5F3F3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _signatureController.clear(),
                  icon: const Icon(Icons.clear, color: Colors.red),
                  label: const Text('Limpiar Firma', style: TextStyle(color: Colors.red)),
                )
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _generarYCompartirPDF,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E352F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.share_rounded),
                label: const Text('Generar y Compartir (WhatsApp)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Manrope')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
