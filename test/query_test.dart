import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('Iniciando prueba de conexión y perfiles...');
  await Supabase.initialize(
    url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );
  
  try {
    final client = Supabase.instance.client;
    print('Consultando tabla profiles...');
    final data = await client.from('profiles').select().limit(5);
    print('DATA: $data');
    
    if (data.isNotEmpty) {
      print('Columnas encontradas: ${data[0].keys.toList()}');
    } else {
      print('La tabla profiles está VACÍA.');
    }
  } catch (e) {
    print('ERROR: $e');
  }
}
