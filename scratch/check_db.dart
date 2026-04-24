import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('--- Verificando Tabla Paradas ---');
    final response = await client.from('paradas').select().limit(1);
    if (response.isNotEmpty) {
      print('Columnas paradas: ${response.first.keys.toList()}');
    } else {
      print('La tabla paradas está vacía.');
    }

    print('--- Verificando Tabla parada_items ---');
    final response2 = await client.from('parada_items').select().limit(1);
    if (response2.isNotEmpty) {
      print('Columnas parada_items: ${response2.first.keys.toList()}');
    } else {
      print('La tabla parada_items está vacía.');
    }
  } catch (e) {
    print('Error: $e');
  }
}
