import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('--- Verificando Tabla Viajes ---');
    final response = await client.from('viajes').select().limit(1);
    if (response.isNotEmpty) {
      print('Columnas detectadas: ${response.first.keys.toList()}');
    } else {
      print('La tabla viajes está vacía.');
    }
  } catch (e) {
    print('Error al consultar viajes: $e');
  }
}
