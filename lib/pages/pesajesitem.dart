import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:easy_debounce/easy_debounce.dart';

class PesajesItemWidget extends StatefulWidget {
  const PesajesItemWidget({super.key, this.paradaItemId});

  final String? paradaItemId;

  static String routeName = 'PesajesItem';
  static String routePath = '/pesajesItem';

  @override
  State<PesajesItemWidget> createState() => _PesajesItemWidgetState();
}

class _PesajesItemWidgetState extends State<PesajesItemWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  String? _tmpSenasa;

  @override
  void dispose() {
    _textController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          automaticallyImplyLeading: false,
          title: Text(
            'Pesajes',
            style: GoogleFonts.interTight(
              color: Colors.white,
              fontSize: 22,
            ),
          ),
          elevation: 2,
        ),
        body: SafeArea(
          child: FutureBuilder<Map<String, dynamic>?>(
            future: widget.paradaItemId != null
                ? Supabase.instance.client
                    .from('parada_items')
                    .select()
                    .eq('id', widget.paradaItemId!)
                    .maybeSingle()
                : Future.value(<String, dynamic>{}),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final itemData = snapshot.data ?? {};
              final cantidad = itemData['cantidad']?.toString() ?? '--';

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final scannedValue = await FlutterBarcodeScanner.scanBarcode(
                              '#C62828', 'Cancel', true, ScanMode.BARCODE,
                            );
                            if (scannedValue != '-1') {
                              setState(() {
                                _tmpSenasa = scannedValue;
                                _textController.text = scannedValue;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E352F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Color(0xFFC68E17)),
                            ),
                          ),
                          child: Text('Escanear', style: GoogleFonts.interTight(color: Colors.white)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _textController,
                            focusNode: _textFieldFocusNode,
                            onChanged: (value) => EasyDebounce.debounce(
                              'textController',
                              const Duration(milliseconds: 2000),
                              () => setState(() => _tmpSenasa = value),
                            ),
                            decoration: InputDecoration(
                              hintText: 'SENASA Code',
                              filled: true,
                              fillColor: Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            maxLength: 11,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cantidad: $cantidad',
                      style: GoogleFonts.inter(),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (_tmpSenasa == null || _tmpSenasa!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Debe ingresar un código de SENASA válido'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } else {
                          // TODO: Perform add action here
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E352F),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFC68E17)),
                        ),
                      ),
                      child: Text('Agregar', style: GoogleFonts.interTight(color: const Color(0xFFFAF9F6))),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
