import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('=== TRACING TRIP DATA ===');
  try {
    // 1. Fetch Trip
    final tripList = await client.from('viajes').select('*').or('viaje_codigo.eq.V-2105-906,viaje_codigo.ilike.%2105%');
    print('Viajes encontrados: ${tripList.length}');
    for (var trip in tripList) {
      final tripId = trip['id'];
      print('\n----------------------------------------');
      print('VIAJE: ID=$tripId, Codigo=${trip['viaje_codigo']}, Estado=${trip['estado']}, ChoferID=${trip['chofer_id']}, Vehiculo=${trip['vehiculo_codigo']}');

      // 2. Fetch Paradas
      final paradas = await client.from('paradas').select('*').eq('viaje_id', tripId).order('orden_secuencia');
      print('  Paradas: ${paradas.length}');
      for (var p in paradas) {
        final pId = p['id'];
        print('    PARADA: ID=$pId, Ubicacion=${p['ubicacion']}, Tipo=${p['tipo']}, Estado=${p['estado']}, SolicitudID=${p['solicitud_id']}');

        // Parada items
        final pItems = await client.from('parada_items').select('*').eq('parada_id', pId);
        for (var pi in pItems) {
          print('      PARADA ITEM: Producto=${pi['producto_codigo']}, Cantidad=${pi['cantidad']}, Unidad=${pi['unidad']}');
        }

        // Referenced Solicitud
        if (p['solicitud_id'] != null) {
          try {
            final sol = await client.from('solicitudes').select('*').eq('id', p['solicitud_id']).maybeSingle();
            if (sol != null) {
              print('      SOLICITUD: ID=${sol['id']}, Tipo=${sol['tipo']}, Producto=${sol['producto']}, Cantidad=${sol['cantidad']}, Estado=${sol['estado']}');
            } else {
              print('      SOLICITUD: No encontrada en DB para ID=${p['solicitud_id']}');
            }
          } catch (e) {
            print('      SOLICITUD Error: $e');
          }
        }
      }

      // 3. Fetch Cargas
      final cargas = await client.from('cargas').select('*').eq('viaje_id', tripId);
      print('  Cargas: ${cargas.length}');
      for (var c in cargas) {
        final cId = c['id'];
        print('    CARGA: ID=$cId, Codigo=${c['carga_codigo']}, Estado=${c['estado']}');
        
        final cItems = await client.from('carga_items').select('*').eq('carga_id', cId);
        print('      Carga Items: ${cItems.length}');
        for (var ci in cItems) {
          print('        CARGA ITEM: Producto=${ci['producto_codigo']}, Cantidad=${ci['cantidad']}, Unidad=${ci['unidad']}');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
