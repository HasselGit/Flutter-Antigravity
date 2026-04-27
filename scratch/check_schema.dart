import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('--- Esquema de Profiles (Primera Fila) ---');
    final response = await client.from('profiles').select().limit(1);
    if (response.isNotEmpty) {
      final p = response.first;
      p.forEach((key, value) {
        print('$key: $value');
      });
    } else {
      print('Tabla vacía');
    }
  } catch (e) {
    print('Error: $e');
  }
}
