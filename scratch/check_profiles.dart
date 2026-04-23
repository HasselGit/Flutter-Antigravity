import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('--- Verificando Tabla Profiles ---');
    final response = await client.from('profiles').select().limit(1);
    if (response.isNotEmpty) {
      print('Columnas detectadas en profiles: ${response.first.keys.toList()}');
    }
  } catch (e) {
    print('Error al consultar profiles: $e');
  }
}
