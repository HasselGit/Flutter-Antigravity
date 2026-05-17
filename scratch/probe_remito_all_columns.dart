import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  final possibleCols = [
    'apicultor_id', 'apicultor_codigo', 'apicultor', 'nombre_apicultor', 'receptor_nombre', 'receptor_dni', 'receptor_tipo', 'firma_base64', 'firma_url', 'pdf_url', 'tipo_operacion', 'viaje_id', 'estado', 'remito_codigo'
  ];
  for (var col in possibleCols) {
    try {
      await client.from('remitos').select(col).limit(1);
      print('Column "$col" exists');
    } catch (e) {
      // Ignorar o depurar
    }
  }
}
