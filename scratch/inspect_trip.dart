import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('--- Buscando viaje V-1105-925 o similar ---');
    final trips = await client.from('viajes').select('*');
    Map<String, dynamic>? targetTrip;
    
    for (var v in trips) {
      final code = v['viaje_codigo']?.toString() ?? '';
      print('Viaje en BD: ID=${v['id']}, Código=$code, Estado=${v['estado']}');
      if (code.contains('1105-925') || code.contains('1005-925')) {
        targetTrip = Map<String, dynamic>.from(v);
      }
    }

    if (targetTrip == null) {
      print('No se encontró viaje con código V-1105-925 o similar.');
      return;
    }

    final String tripId = targetTrip['id'].toString();
    print('\n>>> Viaje encontrado:');
    print(targetTrip);

    // Buscar paradas
    final paradas = await client.from('paradas').select('*').eq('viaje_id', tripId);
    print('\nParadas encontradas (${paradas.length}):');
    final List<String> paradaIds = [];
    for (var p in paradas) {
      print('Parada ID: ${p['id']}, Secuencia: ${p['orden_secuencia']}, Solicitud ID: ${p['solicitud_id']}');
      paradaIds.add(p['id'].toString());
    }

    // Buscar rutas
    final rutas = await client.from('rutas').select('*').eq('viaje_id', tripId);
    print('\nRutas encontradas (${rutas.length}):');
    for (var r in rutas) {
      print('Ruta ID: ${r['id']}, Código: ${r['ruta_codigo']}, Estado: ${r['estado']}');
    }

    // Buscar remitos
    if (paradaIds.isNotEmpty) {
      final remitos = await client.from('remitos').select('*').inFilter('parada_id', paradaIds);
      print('\nRemitos encontrados (${remitos.length}):');
      for (var r in remitos) {
        print('Remito ID: ${r['id']}, Parada ID: ${r['parada_id']}, Número: ${r['numero_remito']}');
      }
    }

    // Buscar cargas
    final cargas = await client.from('cargas').select('*').eq('viaje_id', tripId);
    print('\nCargas encontradas (${cargas.length}):');
    for (var c in cargas) {
      print('Carga ID: ${c['id']}, Código: ${c['carga_codigo']}');
    }

    // Buscar gastos
    final gastos = await client.from('gastos').select('*').eq('viaje_id', tripId);
    print('\nGastos encontrados (${gastos.length}):');
    for (var g in gastos) {
      print('Gasto ID: ${g['id']}, Categoria: ${g['categoria']}, Monto: ${g['monto']}');
    }

  } catch (e) {
    print('Error: $e');
  }
}
