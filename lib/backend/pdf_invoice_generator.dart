import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfInvoiceGenerator {
  // Brand colors
  static final PdfColor primaryColor = PdfColor.fromHex('#1E293B'); // Slate 800 (Professional Slate)
  static final PdfColor accentColor = PdfColor.fromHex('#D97706');  // Amber 600 (Honey Gold)
  static final PdfColor secondaryColor = PdfColor.fromHex('#0D9488'); // Teal 600 (Logistics Teal)
  static final PdfColor backgroundColor = PdfColor.fromHex('#F8FAFC'); // Cool Grey 50
  static final PdfColor borderColor = PdfColor.fromHex('#E2E8F0');     // Cool Grey 200

  // 1. Geomiel Hexagonal Honeycomb Logo Vector Builder (Fallback)
  static pw.Widget _buildGeomielLogo() {
    return pw.Container(
      width: 38,
      height: 38,
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFFBEB'), // Amber 50
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: accentColor, width: 2),
      ),
      alignment: pw.Alignment.center,
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          // Inner core 'G'
          pw.Text(
            'G',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: accentColor,
            ),
          ),
          // Small decorative dots to simulate cells
          pw.Positioned(
            top: 2,
            right: 2,
            child: pw.Container(width: 4, height: 4, decoration: pw.BoxDecoration(color: accentColor, shape: pw.BoxShape.circle)),
          ),
          pw.Positioned(
            bottom: 2,
            left: 2,
            child: pw.Container(width: 4, height: 4, decoration: pw.BoxDecoration(color: accentColor, shape: pw.BoxShape.circle)),
          ),
        ],
      ),
    );
  }

  // 2. GeoLogística Sleek Arrow/Pin Logo Vector Builder
  static pw.Widget _buildGeologisticaLogo() {
    return pw.Container(
      width: 32,
      height: 32,
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F0FDFA'), // Teal 50
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: secondaryColor, width: 2),
      ),
      alignment: pw.Alignment.center,
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          pw.Container(
            width: 14,
            height: 14,
            decoration: pw.BoxDecoration(
              color: secondaryColor,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Container(
            width: 6,
            height: 6,
            decoration: const pw.BoxDecoration(
              color: PdfColors.white,
              shape: pw.BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  // 3. Shared Header showing both Geomiel (PNG logo or fallback) and GeoLogística
  static pw.Widget _buildHeader(String docTitle, String? subtitle, Uint8List? logoBytes) {
    pw.Widget geomielLogoWidget;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      geomielLogoWidget = pw.Container(
        width: 50,
        height: 50,
        alignment: pw.Alignment.center,
        child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
      );
    } else {
      geomielLogoWidget = _buildGeomielLogo();
    }

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Left: Geomiel Logo + Text with exact address
            pw.Row(
              children: [
                geomielLogoWidget,
                pw.SizedBox(width: 10),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'GEOMIEL',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: accentColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pw.Text(
                      'J. Sampayo 180, General Pico, La Pampa',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Apicultura y Producción de Precisión',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ],
            ),
            // Right: GeoLogística System Badge
            pw.Row(
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'GeoLogística',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: secondaryColor,
                      ),
                    ),
                    pw.Text(
                      'Logística & Control de Tránsito',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                    ),
                  ],
                ),
                pw.SizedBox(width: 8),
                _buildGeologisticaLogo(),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 1.5, color: accentColor),
        pw.SizedBox(height: 15),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              docTitle.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            if (subtitle != null)
              pw.Text(
                subtitle,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey600,
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 15),
      ],
    );
  }

  // 4. Metadata details card builder
  static pw.Widget _buildMetadataCard(List<List<String>> data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: backgroundColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: borderColor),
      ),
      child: pw.Table(
        children: data.map((row) {
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Text(
                  row[0],
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey800),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Text(
                  row[1],
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              if (row.length > 2) ...[
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Text(
                    row[2],
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey800),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Text(
                    row[3],
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ]
            ],
          );
        }).toList(),
      ),
    );
  }

  // 5. Generate Professional PDF for Client Remitos (remito_page.dart)
  static Future<Uint8List> generateClientRemitoPDF({
    required String paradaId,
    required String tipoOperacion,
    required String? vehiculoCodigo,
    required String? viajeCodigo,
    required String apicultorNombre,
    required String apicultorLocalidad,
    required String receptorNombre,
    required String receptorDni,
    required List<Map<String, dynamic>> items,
    required double totalBruto,
    required double totalNeto,
    required Uint8List signatureBytes,
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final humanId = 'REM-${paradaId.split('-').first.toUpperCase()}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Branded Header
              _buildHeader('REMITO DIGITAL DE CLIENTE', 'GeoLogística Verified', logoBytes),

              // Metadata section
              _buildMetadataCard([
                ['Comprobante:', humanId, 'Fecha de Emisión:', fecha],
                ['Tipo de Operación:', tipoOperacion, 'Vehículo Asignado:', vehiculoCodigo ?? 'S/D'],
                ['Código de Viaje:', viajeCodigo ?? 'S/D', 'Localidad de Parada:', apicultorLocalidad],
              ]),

              pw.SizedBox(height: 20),

              // Apicultor & Receiver info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CLIENTE / PRODUCTOR:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor)),
                        pw.SizedBox(height: 4),
                        pw.Text(apicultorNombre, style: const pw.TextStyle(fontSize: 11)),
                        pw.Text(apicultorLocalidad, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RECEPCIÓN AUTORIZADA:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor)),
                        pw.SizedBox(height: 4),
                        pw.Text(receptorNombre, style: const pw.TextStyle(fontSize: 11)),
                        if (receptorDni.isNotEmpty)
                          pw.Text('DNI/CUIT: $receptorDni', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Items table
              pw.Text('DETALLE DE OPERACIÓN DE MATERIALES:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Código Producto', 'Cantidad', 'Unidad de Medida', 'Peso Estimado (KG)'],
                data: items.map((item) {
                  final qty = item['cantidad']?.toString() ?? '0';
                  final weight = item['peso_kg'] != null 
                      ? double.tryParse(item['peso_kg'].toString())?.toStringAsFixed(1) ?? '0.0'
                      : '0.0';
                  return [
                    item['producto_codigo'] ?? '-',
                    qty,
                    item['unidad'] ?? 'unidades',
                    weight,
                  ];
                }).toList(),
                headerDecoration: pw.BoxDecoration(color: primaryColor),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  1: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
              ),

              pw.SizedBox(height: 15),

              // Total weight summary banner (only if values are available)
              if (totalBruto > 0 || totalNeto > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: backgroundColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Row(
                        children: [
                          if (totalBruto > 0) ...[
                            pw.Text('Total Bruto: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                            pw.Text('${totalBruto.toStringAsFixed(1)} kg', style: const pw.TextStyle(fontSize: 9)),
                            pw.SizedBox(width: 15),
                          ],
                          if (totalNeto > 0) ...[
                            pw.Text('Total Neto Estimado: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: secondaryColor)),
                            pw.Text('${totalNeto.toStringAsFixed(1)} kg', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              pw.Spacer(),

              // Corporate certification note
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: backgroundColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'Este remito digital ha sido emitido en campo por Geomiel utilizando la plataforma logística GeoLogística. \n'
                    'Para cualquier consulta o validación de trazabilidad de miel, contacte al Depósito Central.',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                  ),
                ),
              ),

              pw.SizedBox(height: 25),

              // Signature section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Verification Stamp
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: secondaryColor, width: 1.5),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'FIRMA DIGITAL VERIFICADA',
                          style: pw.TextStyle(color: secondaryColor, fontWeight: pw.FontWeight.bold, fontSize: 7),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Fecha de firma: $fecha', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
                    ],
                  ),
                  // Signature Field
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 140,
                        height: 55,
                        alignment: pw.Alignment.center,
                        child: pw.Image(pw.MemoryImage(signatureBytes), fit: pw.BoxFit.contain),
                      ),
                      pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                      pw.SizedBox(height: 4),
                      pw.Text('Firma de Conformidad', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      pw.Text(receptorNombre, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  // 6. Generate Professional PDF for Weighing Multi-Remitos (remito_registro.dart)
  static Future<Uint8List> generateWeighingRemitoPDF({
    required String paradaId,
    required String tipoOperacion,
    required String? vehiculoCodigo,
    required String? viajeCodigo,
    required String? titularNombre,
    required String? titularDni,
    required String receptorNombre,
    required String receptorDni,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> pesajes,
    required double totalBruto,
    required double totalTara,
    required double totalNeto,
    required Uint8List signatureBytes,
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final humanId = 'REM-${paradaId.split('-').first.toUpperCase()}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Branded Header
              _buildHeader('REMITO DE BASCULA Y CONFORMIDAD', 'Certificado Geomiel', logoBytes),

              // Metadata section
              _buildMetadataCard([
                ['Comprobante:', humanId, 'Fecha de Pesaje:', fecha],
                ['Tipo de Operación:', tipoOperacion, 'Vehículo Asignado:', vehiculoCodigo ?? 'S/D'],
                ['Código de Viaje:', viajeCodigo ?? 'S/D', 'ID de Parada:', paradaId.split('-').first.toUpperCase()],
              ]),

              pw.SizedBox(height: 15),

              // Apicultor & Receiver info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('APICULTOR TITULAR:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor)),
                        pw.SizedBox(height: 3),
                        pw.Text(titularNombre ?? 'Sin nombre', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        if (titularDni != null && titularDni.isNotEmpty)
                          pw.Text('DNI/CUIT Categoria: $titularDni', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('FIRMATE / RESPONSABLE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor)),
                        pw.SizedBox(height: 3),
                        pw.Text(receptorNombre, style: const pw.TextStyle(fontSize: 10)),
                        if (receptorDni.isNotEmpty)
                          pw.Text('DNI/CUIT Receptor: $receptorDni', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 15),

              // Items summary table
              pw.Text('RESUMEN DE PRODUCTOS DECLARADOS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Código Producto', 'Cantidad Declarada', 'Unidad de Medida'],
                data: items.map((item) => [
                  item['producto_codigo'] ?? '-',
                  item['cantidad']?.toString() ?? '0',
                  item['unidad'] ?? 'unidades',
                ]).toList(),
                headerDecoration: pw.BoxDecoration(color: primaryColor),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {1: pw.Alignment.centerRight},
              ),

              pw.SizedBox(height: 15),

              // Weighing details (drum balance scales)
              if (pesajes.isNotEmpty) ...[
                pw.Text('DESGLOSE DE PESAJE DE TAMBORES (BALANZA DE CAMPO):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor)),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headers: ['N° Tambor', 'Código SENASA de Origen', 'Peso Bruto (KG)', 'Tara Promedio (KG)', 'Peso Neto Real (KG)'],
                  data: List.generate(pesajes.length, (index) {
                    final pItem = pesajes[index];
                    final bruto = (pItem['peso_bruto'] as num?)?.toDouble() ?? 0.0;
                    final tara = (pItem['tara'] as num?)?.toDouble() ?? 0.0;
                    final neto = bruto - tara;
                    final senasa = pItem['senasa_codigo'] ?? 'S/D';
                    return [
                      'Tambor #${index + 1}',
                      senasa,
                      bruto.toStringAsFixed(1),
                      tara.toStringAsFixed(1),
                      neto.toStringAsFixed(1),
                    ];
                  }),
                  headerDecoration: pw.BoxDecoration(color: secondaryColor),
                  headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellAlignments: {
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                    4: pw.Alignment.centerRight,
                  },
                ),
                pw.SizedBox(height: 10),

                // Total weight highlighting board
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#FEF3C7'), // Light Amber 100
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        border: pw.Border.all(color: accentColor, width: 1.5),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text('TOTAL BRUTO: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.Text('${totalBruto.toStringAsFixed(1)} kg | ', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('TOTAL TARA: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.Text('${totalTara.toStringAsFixed(1)} kg | ', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('TOTAL NETO DE MIEL: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: accentColor)),
                          pw.Text('${totalNeto.toStringAsFixed(1)} kg', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accentColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              pw.Spacer(),

              // Professional certification and compliance text
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: backgroundColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'Este remito digital de báscula física certifica que los pesos indicados arriba fueron reconciliados\n'
                    'y verificados en balanza oficial de campo del vehículo de transporte de la plataforma GeoLogística de Geomiel.',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                  ),
                ),
              ),

              pw.SizedBox(height: 15),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: accentColor, width: 1.5),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'CERTIFICADO DE TRÁNSITO GEOMIEL',
                          style: pw.TextStyle(color: accentColor, fontWeight: pw.FontWeight.bold, fontSize: 7),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Validación de pesaje: $fecha', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 130,
                        height: 50,
                        alignment: pw.Alignment.center,
                        child: pw.Image(pw.MemoryImage(signatureBytes), fit: pw.BoxFit.contain),
                      ),
                      pw.Container(width: 130, height: 1, color: PdfColors.grey400),
                      pw.SizedBox(height: 4),
                      pw.Text('Firma de Conformidad', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      pw.Text(receptorNombre, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  // 7. Generate Professional PDF for Warehouse Load Manifests (remito_carga_page.dart)
  static Future<Uint8List> generateCargaManifestPDF({
    required String cargaCodigo,
    required String viajeCodigo,
    required String choferNombre,
    required String vehiculoCodigo,
    required String updatedAtDate,
    required List<Map<String, dynamic>> items,
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(updatedAtDate));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Branded Header
              _buildHeader('MANIFIESTO Y REMITO DE CARGA', 'Operación de Depósito Central', logoBytes),

              // Metadata card
              _buildMetadataCard([
                ['Código de Manifiesto:', cargaCodigo, 'Fecha de Despacho:', dateStr],
                ['Código de Viaje:', viajeCodigo, 'Vehículo / Patente:', vehiculoCodigo],
                ['Chofer Asignado:', choferNombre, 'Estado de Carga:', 'DESPACHADA / CONFIRMADA'],
              ]),

              pw.SizedBox(height: 25),

              // Items table
              pw.Text('MATERIALES Y PRODUCTOS EMBARCADOS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: primaryColor)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Producto Código', 'Descripción Master', 'Cantidad Embarcada', 'Unidad'],
                data: items.map((item) {
                  final String code = item['producto_codigo'] ?? '-';
                  return [
                    code,
                    code == 'TCM' ? 'Tambor Vacío Metálico' : 
                    code == 'TCP' ? 'Tambor Vacío Plástico' : 
                    code == 'AZ' ? 'Azúcar de Alimentación (Bolsas)' : 
                    code == 'AL' ? 'Alimento Líquido Proteico' : 
                    code == 'CERA' ? 'Cera Estampada (Paquetes)' : 
                    'Material Apícola Diverso',
                    item['cantidad']?.toString() ?? '0',
                    item['unidad'] ?? 'unidades',
                  ];
                }).toList(),
                headerDecoration: pw.BoxDecoration(color: primaryColor),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  2: pw.Alignment.centerRight,
                },
              ),

              pw.Spacer(),

              // Warehouse stamps and notes
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: secondaryColor, width: 1.5),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'DESPACHO CONCILIADO - DEPOSITO CENTRAL',
                          style: pw.TextStyle(color: secondaryColor, fontWeight: pw.FontWeight.bold, fontSize: 8),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Control e Inventario verificado digitalmente.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 140,
                        height: 50,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300, style: pw.BorderStyle.dashed),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'CONTROLADO Y EMITIDO\nPOR SISTEMA',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Firma del Encargado de Depósito', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 20),
              
              pw.Divider(color: borderColor),
              pw.Center(
                child: pw.Text(
                  'Este documento constituye un manifiesto de carga oficial para tránsito interno y control de inventario de Geomiel.',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }
}
