import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../backend/design_tokens.dart';

class RemitoCargaPageWidget extends StatefulWidget {
  final String cargaId;

  const RemitoCargaPageWidget({super.key, required this.cargaId});

  @override
  State<RemitoCargaPageWidget> createState() => _RemitoCargaPageWidgetState();
}

class _RemitoCargaPageWidgetState extends State<RemitoCargaPageWidget> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _carga;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('cargas')
          .select('*, viaje:viaje_id(*, profiles(nombre, apellido), vehiculos:vehiculo_codigo(*)), carga_items(*)')
          .eq('id', widget.cargaId)
          .maybeSingle();

      if (res == null) throw Exception('Carga no encontrada');
      
      setState(() {
        _carga = res;
        _items = List<Map<String, dynamic>>.from(res['carga_items'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _shareWhatsApp() async {
    final code = _carga?['carga_codigo'] ?? 'S/C';
    final viaje = _carga?['viaje']?['viaje_codigo'] ?? 'S/V';
    final chofer = '${_carga?['viaje']?['profiles']?['nombre'] ?? ''} ${_carga?['viaje']?['profiles']?['apellido'] ?? ''}'.trim();
    
    String itemsText = '';
    for (var it in _items) {
      itemsText += '\n• ${it['producto_codigo']}: ${it['cantidad']} ${it['unidad']}';
    }

    final String text = '* GeoLogística - Remito de Carga *\n\n'
        'ID Carga: $code\n'
        'Viaje: $viaje\n'
        'Chofer: $chofer\n'
        'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(_carga?['updated_at'] ?? DateTime.now().toIso8601String()))}\n'
        '\n*Detalle:*$itemsText\n\n'
        'Confirmado por Depósito.';

    final String url = 'https://wa.me/?text=${Uri.encodeComponent(text)}';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
    }
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final date = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(_carga?['updated_at'] ?? DateTime.now().toIso8601String()));
    final chofer = '${_carga?['viaje']?['profiles']?['nombre'] ?? ''} ${_carga?['viaje']?['profiles']?['apellido'] ?? ''}'.trim();

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
                  pw.Text('REMITO DE CARGA', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('GeoLogística', style: pw.TextStyle(fontSize: 18, color: PdfColors.green900)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text('Código: ${_carga?['carga_codigo'] ?? 'S/C'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Fecha de Salida: $date', style: pw.TextStyle(color: PdfColors.grey700)),
              pw.Divider(),
              pw.SizedBox(height: 15),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Viaje: ${_carga?['viaje']?['viaje_codigo'] ?? 'S/V'}'),
                      pw.Text('Chofer: $chofer'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Vehículo: ${_carga?['viaje']?['vehiculo_codigo'] ?? 'S/D'}'),
                      pw.Text('Estado: TERMINADO'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 25),
              pw.Text('DETALLE DE CARGA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Producto', 'Cantidad', 'Unidad'],
                data: _items.map((it) => [
                  it['producto_codigo'] ?? '-',
                  it['cantidad']?.toString() ?? '0',
                  it['unidad'] ?? '-'
                ]).toList(),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              ),
              pw.Spacer(),
              pw.Center(
                child: pw.Text('Documento Digital de Uso Interno - Depósito Central', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!)));

    final code = _carga?['carga_codigo'] ?? 'S/C';
    final via = _carga?['viaje']?['viaje_codigo'] ?? 'S/V';

    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        title: Text('Remito de Carga', style: DesignTokens.headlineStyle().copyWith(fontSize: 17)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('COMPROBANTE DIGITAL', style: TextStyle(color: DesignTokens.secondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                          Text(code, style: DesignTokens.headlineStyle().copyWith(fontSize: 24)),
                        ],
                      ),
                      const Icon(Icons.qr_code_2, size: 48, color: DesignTokens.primary),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
                  _infoRow('Viaje', via),
                  _infoRow('Fecha', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(_carga?['updated_at'] ?? DateTime.now().toIso8601String()))),
                  _infoRow('Vehículo', _carga?['viaje']?['vehiculo_codigo'] ?? 'S/D'),
                  const SizedBox(height: 20),
                  const Text('DETALLE DE ÍTEMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  ..._items.map((it) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(child: Text(it['producto_codigo'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                        Text('${it['cantidad']} ${it['unidad']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _shareWhatsApp,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('ENVIAR POR WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _generatePdf,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: DesignTokens.primary), foregroundColor: DesignTokens.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('VER PDF / IMPRIMIR', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary)),
        ],
      ),
    );
  }
}
