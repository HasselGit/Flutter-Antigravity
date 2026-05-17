import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Verificando Buckets de Storage (New Key) ---');
  try {
    final buckets = await client.storage.listBuckets();
    print('Buckets encontrados: ${buckets.length}');
    for (var b in buckets) {
      print(' - ID: "${b.id}" (Nombre: "${b.name}", Público: ${b.public})');
    }
  } catch (e) {
    print('Error al listar buckets: $e');
  }
}
