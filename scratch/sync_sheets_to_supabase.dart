import 'package:supabase/supabase.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('--- INICIANDO SINCRONIZACIÓN GOOGLE SHEET -> SUPABASE (V2) ---');

  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final gSheetId = '1vcg7nmkTfp_AyTTkTOGuGu7k-B2eAAUA_V8P24wa1Es';

  // 1. Sincronizar Vehículos
  print('\nSincronizando Vehículos...');
  final vehiculosCsv = await _fetchCsv(gSheetId, '1803032168');
  for (var i = 1; i < vehiculosCsv.length; i++) {
    final row = vehiculosCsv[i];
    if (row.length < 4) continue;
    try {
      await client.from('vehiculos').upsert({
        'vehiculo_codigo': row[0], // Corregido: vehiculo_codigo en lugar de codigo
        'marca': row[1],
        'modelo': row[2],
        'patente': row[3],
        'capacidad_kg': 15000,
        'capacidad_tambores': 48,
      });
      print('  OK: ${row[0]}');
    } catch (e) { print('  Error en ${row[0]}: $e'); }
  }

  // 2. Sincronizar Apicultores
  print('\nSincronizando Apicultores (114 registros)...');
  final apicultoresCsv = await _fetchCsv(gSheetId, '1388406787');
  for (var i = 1; i < apicultoresCsv.length; i++) {
    final row = apicultoresCsv[i];
    if (row.length < 3) continue;
    
    // Normalizar ID: Asegurar que tenga el formato 'A0XXXX' si es necesario
    String rawId = row[0].toString().replaceAll('A', '').trim();
    if (rawId.isEmpty) continue;
    String idNormalizado = 'A${rawId.padLeft(5, '0')}';

    try {
      await client.from('apicultores').upsert({
        'id': idNormalizado,
        'nombre': row[1],
        'localidad': row[2],
        'provincia': row.length > 3 ? row[3] : '',
        'cuit': row.length > 5 ? row[5] : '',
        'telefono': row.length > 7 ? row[7] : '',
      });
      if (i % 20 == 0) print('  Procesados $i...');
    } catch (e) { print('  Error en ${row[1]}: $e'); }
  }

  // 3. Sincronizar Solicitudes (Necesidades)
  print('\nSincronizando Solicitudes...');
  final solicitudesCsv = await _fetchCsv(gSheetId, '999329721');
  for (var i = 1; i < solicitudesCsv.length; i++) {
    final row = solicitudesCsv[i];
    if (row.length < 5) continue;
    
    // Normalizar ID del apicultor para que coincida con la tabla apicultores
    String rawApiId = row[2].toString().replaceAll('A', '').trim();
    String apiIdNormalizado = 'A${rawApiId.padLeft(5, '0')}';

    try {
      await client.from('solicitudes').upsert({
        'solicitud_codigo': row[1], 
        'apicultor_id': apiIdNormalizado, // Usar ID normalizado
        'producto': row[3],
        'cantidad': double.tryParse(row[4].toString()) ?? 0,
        'tipo': row[5],
        'localidad': row[6],
        'estado': 'Pendiente',
      });
      print('  OK: ${row[1]}');
    } catch (e) { print('  Error en ${row[1]}: $e'); }
  }

  print('\n--- SINCRONIZACIÓN FINALIZADA ---');
}

Future<List<List<String>>> _fetchCsv(String id, String gid) async {
  final url = 'https://docs.google.com/spreadsheets/d/$id/export?format=csv&gid=$gid';
  final response = await http.get(Uri.parse(url));
  final lines = CsvToListConverter().convert(response.body);
  return lines.map((l) => l.map((e) => e.toString()).toList()).toList();
}

class CsvToListConverter {
  List<List<dynamic>> convert(String input) {
    return input.split('\n').where((l) => l.trim().isNotEmpty).map((line) {
      // Manejo básico de comas dentro de comillas si fuera necesario, 
      // pero para este caso el split simple suele bastar
      return line.split(',');
    }).toList();
  }
}
