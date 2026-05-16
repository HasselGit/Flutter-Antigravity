import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Verificando Tablas Secundarias ---');
  
  final checks = {
    'remitos': ['id', 'parada_id', 'fecha_emision', 'estado', 'apicultor_nombre', 'apicultor_dni', 'firma_base64'],
    'apicultores': ['id', 'nombre', 'cuit', 'dni', 'localidad'],
    'pesajes': ['id', 'parada_id', 'tcm_numero', 'bruto', 'tara', 'neto'],
  };

  for (var table in checks.entries) {
    print('\nTabla: ${table.key}');
    for (var col in table.value) {
      try {
        await client.from(table.key).select(col).limit(1);
        print('  [OK] "$col"');
      } catch (e) {
        print('  [FAIL] "$col": $e');
      }
    }
  }
}
