import 'package:supabase_flutter/supabase_flutter.dart';

// Definición mínima de estados para no depender de otros archivos en el script
class States {
  static const String pendiente  = 'Pendiente';
  static const String asignada   = 'Asignada';
  static const String enCurso    = 'En Curso';
  static const String terminado  = 'Terminado';

  static String normalize(dynamic val) {
    final clean = val?.toString().toLowerCase().trim() ?? '';
    if (clean == 'pendiente' || clean == 'solicitado') return pendiente;
    if (clean == 'planificado' || clean == 'planificada' || clean == 'cargado') return pendiente;
    if (clean == 'en proceso' || clean == 'en curso' || clean == 'enproceso' || clean == 'encurso') return enCurso;
    if (clean.contains('terminado') || clean.contains('finalizado')) return terminado;
    if (clean.contains('asignada')) return asignada;
    return pendiente;
  }
}

void main() async {
  print('Iniciando auditoría de estados de solicitudes...');
  
  await Supabase.initialize(
    url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );
  
  final client = Supabase.instance.client;
  
  // 1. Obtener todas las solicitudes
  final sols = await client.from('solicitudes')
      .select('id, estado, apicultor_id, producto')
      .neq('estado', 'Terminada');
  
  print('Analizando ${sols.length} solicitudes activas...');
  
  int fixedCount = 0;
  
  for (var s in sols) {
    final solId = s['id'].toString();
    final currentEstado = s['estado']?.toString() ?? 'Pendiente';
    
    // Buscar si está en alguna parada de un viaje
    // Primero en la parada directamente
    var parada = await client.from('paradas')
        .select('id, viaje_id, viajes(estado)')
        .eq('solicitud_id', solId)
        .maybeSingle();
        
    // Si no está, buscar en parada_items
    if (parada == null) {
      final item = await client.from('parada_items')
          .select('parada_id, paradas(viaje_id, viajes(estado))')
          .eq('solicitud_id', solId)
          .maybeSingle();
      if (item != null && item['paradas'] != null) {
        parada = item['paradas'];
      }
    }
    
    if (parada == null) {
      // No está en un viaje, debería ser Pendiente
      if (currentEstado != 'Pendiente' && currentEstado != 'Solicitado') {
        print('FIX: Solicitud $solId (${s['producto']}) -> Pendiente (estaba $currentEstado)');
        await client.from('solicitudes').update({'estado': 'Pendiente'}).eq('id', solId);
        fixedCount++;
      }
    } else {
      // Está en un viaje, ver el estado del viaje
      final viajeRaw = parada['viajes'];
      if (viajeRaw != null) {
        final vEstado = States.normalize(viajeRaw['estado']);
        String targetEstado;
        
        if (vEstado == States.enCurso) {
          targetEstado = States.enCurso;
        } else if (vEstado == States.terminado) {
          targetEstado = States.terminado;
        } else {
          targetEstado = States.asignada;
        }
        
        if (currentEstado != targetEstado) {
          print('FIX: Solicitud $solId (${s['producto']}) -> $targetEstado (estaba $currentEstado, viaje era $vEstado)');
          await client.from('solicitudes').update({'estado': targetEstado}).eq('id', solId);
          fixedCount++;
        }
      }
    }
  }
  
  print('Auditoría finalizada. Se corrigieron $fixedCount solicitudes.');
}
