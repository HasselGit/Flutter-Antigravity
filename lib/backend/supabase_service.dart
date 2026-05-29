import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'productos_data.dart';
import 'app_states.dart';
import 'apicultores_data.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ─── AUTH ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();
    try {
      print('SupabaseService: Intentando login para $cleanEmail');
      
      // Limpiar cualquier sesión vieja/stale de Supabase Auth
      try {
        await _client.auth.signOut();
        print('SupabaseService: Sesión previa cerrada antes del login manual para garantizar anon RLS');
      } catch (_) {}

      // Buscamos solo por email primero para ser más flexibles
      final profile = await _client.from('profiles')
          .select()
          .ilike('email', cleanEmail)
          .maybeSingle();
      
      if (profile != null) {
        // Verificación manual de contraseña para evitar errores de tipo en la DB
        final dbPass = profile['contrasena']?.toString() ?? '';
        if (dbPass == cleanPass) {
          return await _saveLocal(profile);
        } else {
          throw Exception('Contraseña incorrecta');
        }
      } else {
        throw Exception('Usuario no encontrado');
      }
    } catch (e) {
      print('SupabaseService: Error en login: $e');
      if (e is TimeoutException) {
        throw Exception('Tiempo de espera agotado. Revisa tu conexión.');
      }
      throw Exception(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  Future<Map<String, dynamic>> _saveLocal(Map<String, dynamic> user) async {
    try {
      print('SupabaseService: Iniciando _saveLocal...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', user['id']?.toString() ?? '');
      await prefs.setString('user_email', user['email'] ?? '');
      await prefs.setString('user_nombre', user['nombre'] ?? '');
      await prefs.setString('user_apellido', user['apellido'] ?? '');
      await prefs.setString('user_puesto', user['puesto'] ?? '');
      print('SupabaseService: _saveLocal completado con éxito');
      return user;
    } catch (e) {
      print('SupabaseService: Error en _saveLocal: $e');
      return user; // Retornamos el user igualmente para no bloquear el flujo si solo falló el guardado persistente
    }
  }

  // ─── VIAJES ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getViajes({String? userId, String? role}) async {
    try {
      List<dynamic> data;
      try {
        // Consulta optimizada con joins para evitar el bucle de queries individuales
        var query = _client.from('viajes').select('*, paradas(*, parada_items(*), remitos(*))');

        if (role == 'Chofer' && userId != null) {
          query = query.eq('chofer_id', userId);
        }

        data = await query
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 15));
      } catch (innerError) {
        print('SupabaseService: getViajes con paradas falló ($innerError). Reintentando consulta simple de viajes.');
        var query = _client.from('viajes').select('*');

        if (role == 'Chofer' && userId != null) {
          query = query.eq('chofer_id', userId);
        }

        data = await query
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 15));
      }

      final viajes = List<Map<String, dynamic>>.from(data);
      for (var v in viajes) {
        v['estado'] = AppStates.normalize(v['estado']);
        // Cargar chofer manualmente para evitar errores de relación
        if (v['chofer_id'] != null) {
          try {
            final chofer = await _client.from('profiles')
                .select('nombre, apellido').eq('id', v['chofer_id']).maybeSingle();
            v['chofer'] = chofer;
          } catch (_) {}
        }
      }
      return viajes;
    } catch (e) {
      print('SupabaseService: Error crítico en getViajes: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getViajeDetalle(dynamic viajeId) async {
    print('SupabaseService: getViajeDetalle convocado para viajeId: $viajeId');
    try {
      // 1. Consulta por wildcard (*) para inmunidad absoluta contra cambios de columnas
      final viajeRaw = await _client.from('viajes')
          .select('*')
          .eq('id', viajeId).maybeSingle();
      
      if (viajeRaw == null) {
        print('SupabaseService: No se encontró ningún viaje con ID $viajeId');
        return null;
      }
      final Map<String, dynamic> viaje = Map<String, dynamic>.from(viajeRaw);
      
      viaje['estado'] = AppStates.normalize(viaje['estado']);
      if (viaje['chofer_id'] != null) {
        try {
          final chofer = await _client.from('profiles')
              .select('nombre, apellido').eq('id', viaje['chofer_id']).maybeSingle();
          viaje['chofer'] = chofer;
        } catch (choferErr) {
          print('SupabaseService: Error cargando chofer: $choferErr');
        }
      }
      
      try {
        print('SupabaseService: Intentando consulta de rutas para viajeId: $viajeId');
        final rutas = await _client.from('rutas')
            .select('*, paradas(*, parada_items(*), remitos(*))')
            .eq('viaje_id', viajeId).order('created_at');
        
        // Verificar si el join anidado devolvió paradas. Si no, hacer query directa.
        final bool paradasVaciasEnRutas = rutas.isNotEmpty &&
            (rutas as List).every((r) => (r['paradas'] as List? ?? []).isEmpty);

        List<dynamic> paradasDirectas = [];
        if (paradasVaciasEnRutas) {
          print('SupabaseService: Join anidado de paradas en rutas vacío, intentando consulta directa de paradas...');
          try {
            paradasDirectas = await _client.from('paradas')
                .select('id, viaje_id, ruta_id, solicitud_id, orden_secuencia, tipo, ubicacion, localidad, estado, remito_id, parada_items(id, producto_codigo, cantidad, unidad), remitos(*)')
                .eq('viaje_id', viajeId).order('orden_secuencia');
          } catch (paradasDirectasErr) {
            print('SupabaseService: Error en paradasDirectas con remitos(*): $paradasDirectasErr. Reintentando sin remitos(*)...');
            try {
              paradasDirectas = await _client.from('paradas')
                  .select('id, viaje_id, ruta_id, solicitud_id, orden_secuencia, tipo, ubicacion, localidad, estado, remito_id, parada_items(id, producto_codigo, cantidad, unidad)')
                  .eq('viaje_id', viajeId).order('orden_secuencia');
            } catch (pDirectasErr2) {
              print('SupabaseService: Error crítico en paradasDirectas simplificado: $pDirectasErr2');
              paradasDirectas = [];
            }
          }

          // Mutar las rutas asignando sus paradas
          for (var r in rutas) {
            final rutaId = r['id']?.toString();
            r['paradas'] = paradasDirectas
                .where((p) => p['ruta_id']?.toString() == rutaId)
                .toList();
            // Si no hay ruta_id coincidente, asignar todas al primer ruta
            if ((r['paradas'] as List).isEmpty && r == rutas.first) {
              r['paradas'] = paradasDirectas.toList();
            }
          }
        }

        viaje['rutas_data'] = rutas;
        
        // Mantener paradas en raíz para compatibilidad legacy
        final List<dynamic> allParadas = [];
        for (var r in rutas) {
          final pList = List<Map<String, dynamic>>.from(r['paradas'] ?? []);
          for (var p in pList) p['ruta_codigo'] = r['ruta_codigo'];
          allParadas.addAll(pList);
        }
        // Si aún no hay paradas en rutas, usar las directas
        if (allParadas.isEmpty && paradasDirectas.isNotEmpty) {
          allParadas.addAll(paradasDirectas);
        }
        viaje['paradas'] = allParadas..sort((a, b) => (a['orden_secuencia'] ?? 0).compareTo(b['orden_secuencia'] ?? 0));
      } catch (rutasErr) { 
        print('SupabaseService: Error en consulta de rutas ($rutasErr). Corriendo fallback directo a paradas...');
        // Fallback a paradas directas si no hay rutas aún
        try {
          final paradas = await _client.from('paradas')
              .select('id, viaje_id, solicitud_id, orden_secuencia, tipo, ubicacion, localidad, estado, remito_id, parada_items(id, producto_codigo, cantidad, unidad), remitos(*)')
              .eq('viaje_id', viajeId).order('orden_secuencia');
          viaje['paradas'] = paradas;
        } catch (paradasErr) {
          print('SupabaseService: Error en paradas fallback con remitos(*): $paradasErr. Reintentando sin remitos(*)...');
          try {
            final paradas = await _client.from('paradas')
                .select('id, viaje_id, solicitud_id, orden_secuencia, tipo, ubicacion, localidad, estado, remito_id, parada_items(id, producto_codigo, cantidad, unidad)')
                .eq('viaje_id', viajeId).order('orden_secuencia');
            viaje['paradas'] = paradas;
          } catch (paradasErr2) {
            print('SupabaseService: Fallback directo a paradas falló de forma crítica: $paradasErr2');
            viaje['paradas'] = [];
          }
        }
      }



      // Auto-synchronize paradas that have remitos but are still in 'Pendiente' or 'En Proceso' state
      try {
        final List<dynamic> paradasList = viaje['paradas'] ?? [];
        for (var p in paradasList) {
          final String estado = AppStates.normalize(p['estado']);
          final List<dynamic> remitos = p['remitos'] as List? ?? [];
          if (remitos.isNotEmpty && estado != AppStates.terminado) {
            final String vehiculoCodigo = viaje['vehiculo_codigo']?.toString() ?? 'CAMION-01';
            await finalizarParada(p['id'].toString(), vehiculoCodigo);
            p['estado'] = AppStates.terminado;
            print('SupabaseService: Auto-finalizada parada ${p['id']} que tenía remito.');
          }
        }
      } catch (e) {
        print('SupabaseService: Error en auto-finalización de parada: $e');
      }

      // ENRICHMENT OF PARADA_ITEMS WITH COMPLETED SOLICITUDES
      try {
        final List<dynamic> paradasList = viaje['paradas'] ?? [];
        if (paradasList.isNotEmpty) {
          // Build maps based on masterCatalog
          final Map<String, String> numericToAlpha = {};
          final Map<String, String> productToUnit = {};
          for (var p in ProductosData.masterCatalog) {
            final numCode = p['codigo']?.toString().trim();
            final alphaCode = p['producto']?.toString().trim().toUpperCase();
            final unit = p['unidad']?.toString() ?? 'uni';
            if (numCode != null && alphaCode != null && alphaCode.isNotEmpty) {
              numericToAlpha[numCode] = alphaCode;
              productToUnit[alphaCode] = unit;
              productToUnit[numCode] = unit;
            }
          }

          final List<String> pSolIds = [];
          final List<String> pShortIds = [];
          for (var p in paradasList) {
            if (p['solicitud_id'] != null) {
              pSolIds.add(p['solicitud_id'].toString());
            }
            if (p['id'] != null) {
              pShortIds.add(p['id'].toString().split('-').first.toUpperCase());
            }
          }

          List<dynamic> allSols = [];
          if (pSolIds.isNotEmpty || pShortIds.isNotEmpty) {
            final List<String> orFilters = [];
            if (pSolIds.isNotEmpty) {
              orFilters.add('id.in.(${pSolIds.join(",")})');
            }
            for (var shortId in pShortIds) {
              orFilters.add('solicitud_codigo.ilike.SOL-REM-$shortId%');
            }

            final res = await _client.from('solicitudes')
                .select('id, solicitud_codigo, producto, cantidad, estado')
                .or(orFilters.join(','));
            allSols = List<dynamic>.from(res ?? []);
          }

          for (var p in paradasList) {
            final String shortId = p['id'].toString().split('-').first.toUpperCase();
            final matchingSols = allSols.where((s) {
              final sId = s['id']?.toString();
              final sCode = s['solicitud_codigo']?.toString() ?? '';
              return (sId != null && sId == p['solicitud_id']?.toString()) ||
                     (sCode.toUpperCase().startsWith('SOL-REM-$shortId'));
            }).toList();

            if (matchingSols.isNotEmpty) {
              // Group and sum completed solicitudes
              final Map<String, Map<String, dynamic>> aggregated = {};
              for (var s in matchingSols) {
                String prod = (s['producto'] ?? '').toString().toUpperCase();
                if (numericToAlpha.containsKey(prod)) {
                  prod = numericToAlpha[prod]!;
                }
                final double qty = (s['cantidad'] as num?)?.toDouble() ?? 0.0;
                final String unit = productToUnit[prod] ?? 'uni';
                final String estado = s['estado']?.toString().toLowerCase() ?? '';

                if (estado.contains('terminada') || estado.contains('terminado')) {
                  if (aggregated.containsKey(prod)) {
                    aggregated[prod]!['cantidad'] = (aggregated[prod]!['cantidad'] as double) + qty;
                  } else {
                    aggregated[prod] = {
                      'producto_codigo': prod,
                      'cantidad': qty,
                      'unidad': unit,
                    };
                  }
                }
              }

              if (aggregated.isNotEmpty) {
                // We have actual completed items! Let's override or update parada_items.
                final List<dynamic> currentItems = p['parada_items'] != null ? List<dynamic>.from(p['parada_items']) : [];
                final List<dynamic> updatedItems = [];

                // For each aggregated item, if it exists in currentItems, update its quantity.
                // Otherwise, add it.
                for (var aggKey in aggregated.keys) {
                  final aggItem = aggregated[aggKey]!;
                  final existing = currentItems.firstWhere((it) {
                    String itCode = (it['producto_codigo'] ?? '').toString().toUpperCase();
                    if (numericToAlpha.containsKey(itCode)) {
                      itCode = numericToAlpha[itCode]!;
                    }
                    return itCode == aggKey;
                  }, orElse: () => null);

                  if (existing != null) {
                    existing['cantidad'] = aggItem['cantidad'];
                    existing['unidad'] = aggItem['unidad'];
                    existing['producto_codigo'] = aggKey; // Ensure standard alpha code
                    updatedItems.add(existing);
                  } else {
                    updatedItems.add(aggItem);
                  }
                }

                // Keep planned items that were NOT part of completed solicitudes but set their quantity to 0 if the stop is completed.
                final bool isParadaTerminada = p['estado']?.toString().toLowerCase().contains('terminad') ?? false;
                for (var it in currentItems) {
                  String itCode = (it['producto_codigo'] ?? '').toString().toUpperCase();
                  if (numericToAlpha.containsKey(itCode)) {
                    itCode = numericToAlpha[itCode]!;
                  }
                  if (!aggregated.containsKey(itCode)) {
                    if (isParadaTerminada) {
                      it['cantidad'] = 0.0; // it didn't happen
                    }
                    it['producto_codigo'] = itCode; // standard to alpha
                    updatedItems.add(it);
                  }
                }

                p['parada_items'] = updatedItems;
              }
            }
          }
        }
      } catch (enrichErr) {
        print('SupabaseService: Error during parada_items enrichment: $enrichErr');
      }

      try {
        final gastos = await _client.from('gastos')
            .select('id, categoria, monto, fecha, comprobante_url')
            .eq('viaje_id', viajeId).order('fecha');
        viaje['gastos'] = gastos;
      } catch (_) { viaje['gastos'] = []; }

      try {
        final cargasRaw = await _client.from('cargas')
            .select('*, carga_items(*)')
            .eq('viaje_id', viajeId).order('created_at');
        
        final List<Map<String, dynamic>> cargas = (cargasRaw as List).map((c) {
          return Map<String, dynamic>.from(c as Map);
        }).toList();

        // Fallback directo si carga_items viene vacío por RLS stale
        for (var c in cargas) {
          final items = c['carga_items'] as List? ?? [];
          if (items.isEmpty) {
            try {
              final directItems = await _client
                  .from('carga_items')
                  .select('*')
                  .eq('carga_id', c['id']);
              c['carga_items'] = directItems;
            } catch (fallbackErr) {
              print('SupabaseService: Error en fallback directo getViajeDetalle carga_items para ${c['id']}: $fallbackErr');
            }
          }
        }
        viaje['cargas'] = cargas;
      } catch (_) { viaje['cargas'] = []; }

      // Fetch and attach gastos directly to the viaje object
      try {
        final gastosRaw = await _client.from('gastos')
            .select('*, profiles(nombre, apellido)')
            .eq('viaje_id', viajeId)
            .order('fecha', ascending: false);
        viaje['gastos'] = gastosRaw;
        print('SupabaseService: Gastos cargados para viaje: ${gastosRaw.length}');
      } catch (gastosErr) {
        print('SupabaseService: Error cargando gastos del viaje: $gastosErr');
        viaje['gastos'] = [];
      }

      return viaje;
    } catch (e) {
      print('SupabaseService: Error en getViajeDetalle: $e');
      return null;
    }
  }

  Future<void> updateViajeEstado(String viajeId, String nuevoEstado) async {
    // Normalizar el estado antes de guardar
    final normalizedNuevo = AppStates.normalize(nuevoEstado);
    final Map<String, dynamic> updates = {'estado': normalizedNuevo};
    
    if (normalizedNuevo == AppStates.enCurso) {
      updates['fecha_inicio'] = DateTime.now().toIso8601String();
    } else if (normalizedNuevo == AppStates.terminado) {
      updates['fecha_terminado'] = DateTime.now().toIso8601String();
    }
    
    await _client.from('viajes').update(updates).eq('id', viajeId);

    // Propagar estado a las solicitudes asociadas de forma selectiva
    try {
      final paradas = await _client.from('paradas')
          .select('solicitud_id')
          .eq('viaje_id', viajeId);
      
      final Set<String> solicitudIds = {};
      for (var p in (paradas as List)) {
        if (p['solicitud_id'] != null) solicitudIds.add(p['solicitud_id'].toString());
      }

      if (solicitudIds.isNotEmpty) {
        if (normalizedNuevo == AppStates.enCurso) {
          // Solo pasar a 'En Curso' las que están 'Asignada'
          await _client.from('solicitudes')
              .update({'estado': AppStates.enCurso})
              .filter('id', 'in', solicitudIds.toList())
              .eq('estado', AppStates.asignada);
        } else if (normalizedNuevo == AppStates.pendiente) {
          // Si el viaje se resetea a Pendiente, las que estaban 'En Curso' vuelven a 'Asignada'
          // Las 'Terminada' se quedan como están.
          await _client.from('solicitudes')
              .update({'estado': AppStates.asignada})
              .filter('id', 'in', solicitudIds.toList())
              .eq('estado', AppStates.enCurso);
        }
        // Nota: El estado 'Terminado' del viaje no debería forzar 'Terminado' en las solicitudes
        // ya que estas se terminan individualmente al generar el remito.
      }
    } catch (e) {
      print('SupabaseService: Error propagando estado a solicitudes: $e');
    }
  }

  Future<void> updateViajeOdometerAndLitros(String viajeId, {double? odometroInicial, double? odometroFinal, String? descripcion}) async {
    final Map<String, dynamic> updates = {};
    if (odometroInicial != null) updates['odometro_inicial'] = odometroInicial;
    if (odometroFinal != null) updates['odometro_final'] = odometroFinal;
    if (descripcion != null) updates['descripcion'] = descripcion;
    
    await _client.from('viajes').update(updates).eq('id', viajeId);
  }

  /// Marca todas las cargas de un viaje que están 'En Proceso' como 'Terminado'.
  /// Las cargas aún en 'Pendiente' se mantienen para que el depósito pueda terminarlas.
  Future<void> confirmarCargaViaje(String viajeId) async {
    final List<dynamic> cargas = await _client.from('cargas')
        .select('id')
        .eq('viaje_id', viajeId)
        .eq('estado', AppStates.enCurso);
    
    for (var c in cargas) {
      await updateCargaEstado(c['id'].toString(), AppStates.terminado);
    }
  }

  /// Cambia el estado de una carga de Pendiente a En Proceso (inicio de carga física).
  Future<void> iniciarCarga(String cargaId) async {
    await _client.from('cargas').update({
      'estado': AppStates.enCurso,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', cargaId);
  }

  /// Reemplaza los ítems de una carga activa (Pendiente o En Proceso).
  /// Elimina los ítems anteriores e inserta los nuevos.
  Future<void> updateCargaItems(String cargaId, List<Map<String, dynamic>> items) async {
    // Borrar ítems existentes
    await _client.from('carga_items').delete().eq('carga_id', cargaId);
    // Insertar nuevos ítems
    if (items.isNotEmpty) {
      final toInsert = items.map((item) => {
        'carga_id': cargaId,
        'producto_codigo': item['producto_codigo'],
        'cantidad': (item['cantidad'] as num).toDouble(),
        'unidad': item['unidad'] ?? 'UN',
      }).toList();
      await _client.from('carga_items').insert(toInsert);
    }
    // Actualizar timestamp
    await _client.from('cargas').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', cargaId);
  }

  Future<List<Map<String, dynamic>>> getTerminatedCargas() async {
    try {
      final res = await _client.from('cargas')
          .select('*, viaje:viaje_id(*, vehiculo:vehiculo_codigo(*)), carga_items(*)')
          .or('estado.eq.Terminado,estado.eq.Terminada')
          .order('updated_at', ascending: false);
      
      final List<Map<String, dynamic>> list = (res as List).map((c) {
        final Map<String, dynamic> cMap = Map<String, dynamic>.from(c as Map);
        if (cMap['viaje'] != null) {
          cMap['viaje'] = Map<String, dynamic>.from(cMap['viaje'] as Map);
        }
        return cMap;
      }).toList();

      for (var c in list) {
        final items = c['carga_items'] as List? ?? [];
        if (items.isEmpty) {
          try {
            final directItems = await _client
                .from('carga_items')
                .select('*')
                .eq('carga_id', c['id']);
            c['carga_items'] = directItems;
          } catch (_) {}
        }
        final viaje = c['viaje'];
        if (viaje != null && viaje['chofer_id'] != null) {
          try {
            final chofer = await _client.from('profiles')
                .select('nombre, apellido')
                .eq('id', viaje['chofer_id'])
                .maybeSingle();
            viaje['profiles'] = chofer;
          } catch (_) {}
        }
      }
      return list;
    } catch (e) {
      print('SupabaseService: Error en getTerminatedCargas: $e');
      return [];
    }
  }

  // ─── RUTAS ────────────────────────────────────────────────────────────────

  Future<void> updateRutaEstado(String rutaId, String nuevoEstado) async {
    final Map<String, dynamic> updates = {'estado': nuevoEstado};
    if (nuevoEstado == AppStates.enCurso) {
      updates['fecha_inicio'] = DateTime.now().toIso8601String();
    } else if (nuevoEstado == AppStates.terminado) {
      updates['fecha_terminado'] = DateTime.now().toIso8601String();
    }
    await _client.from('rutas').update(updates).eq('id', rutaId);
  }

  Future<void> solicitarCambioRuta({required String rutaId, required String paradaId}) async {
    await _client.from('rutas').update({
      'cambio_solicitado': true,
      'cambio_solicitado_en_parada_id': paradaId,
    }).eq('id', rutaId);
  }

  Future<void> aprobarCambioRuta({required String rutaId, required String rolAprobador}) async {
    await _client.from('rutas').update({
      'cambio_solicitado': false,
      'aprobado_por_rol': rolAprobador,
    }).eq('id', rutaId);
  }

  // ─── STATS ────────────────────────────────────────────────────────────────

  Future<Map<String, int>> getStats({String? userId, String? role}) async {
    try {
      dynamic query = _client.from('viajes').select('estado');
      if (role == 'Chofer' && userId != null) {
        query = query.eq('chofer_id', userId);
      }
      
      final data = await query.timeout(const Duration(seconds: 15));
      int pendientes = 0, enCurso = 0, terminados = 0;
      
      for (final v in (data as List)) {
        final e = AppStates.normalize(v['estado']);
        if (e == AppStates.pendiente) pendientes++;
        else if (e == AppStates.enCurso) enCurso++;
        else if (e == AppStates.terminado) terminados++;
      }
      return {'planificados': pendientes, 'en_curso': enCurso, 'terminados': terminados};
    } catch (e) {
      print('SupabaseService: Error en getStats: $e');
      return {'planificados': 0, 'en_curso': 0, 'terminados': 0};
    }
  }

  Future<Map<String, int>> getCargasStats({String? userId, String? role}) async {
    try {
      dynamic query = _client.from('cargas').select('estado');
      // Podríamos filtrar por depósito origen/destino si fuese necesario, pero por ahora mostramos todas las cargas activas
      
      final data = await query.timeout(const Duration(seconds: 15));
      int pendientes = 0, enCurso = 0, terminadas = 0;
      
      for (final c in (data as List)) {
        final e = AppStates.normalize(c['estado']);
        if (e == AppStates.pendiente) pendientes++;
        else if (e == AppStates.enCurso) enCurso++;
        else if (e == AppStates.terminado) terminadas++;
      }
      return {'planificadas': pendientes, 'en_curso': enCurso, 'terminadas': terminadas};
    } catch (e) {
      print('SupabaseService: Error en getCargasStats: $e');
      return {'planificadas': 0, 'en_curso': 0, 'terminadas': 0};
    }
  }

  Future<Map<String, dynamic>> getGerenteStats() async {
    try {
      // 1. Carga total en Kg (de paradas)
      final paradasData = await _client.from('paradas')
          .select('carga_kg').not('carga_kg', 'is', null).timeout(const Duration(seconds: 10));
      double totalKg = (paradasData as List).fold(0.0, (sum, p) => sum + ((p['carga_kg'] as num?)?.toDouble() ?? 0));

      // 2. Viajes activos (en curso)
      final viajesDataRaw = await _client.from('viajes')
          .select('id, viaje_codigo, vehiculo_codigo, chofer_id, estado, fecha, descripcion')
          .eq('estado', AppStates.enCurso).timeout(const Duration(seconds: 10));
      final viajesData = List<Map<String, dynamic>>.from(viajesDataRaw);
      for (var v in viajesData) {
        if (v['chofer_id'] != null) {
          try {
            final chofer = await _client.from('profiles')
                .select('nombre, apellido').eq('id', v['chofer_id']).maybeSingle();
            v['profiles'] = chofer;
          } catch (_) {}
        }
      }

      // 3. Stock de tambores (de pesajes)
      final pesajesData = await _client.from('pesajes').select('id').timeout(const Duration(seconds: 10));
      final int tamboresStock = (pesajesData as List).length;

      // 4. Conteo de todos los viajes por estado
      final viajesAllRaw = await _client.from('viajes').select('estado').timeout(const Duration(seconds: 10));
      int viajesPendientes = 0;
      int viajesEnCursoCount = 0;
      int viajesTerminados = 0;
      for (var v in (viajesAllRaw as List)) {
        final estado = AppStates.normalize(v['estado']);
        if (estado == AppStates.pendiente || estado == 'Planificado') {
          viajesPendientes++;
        } else if (estado == AppStates.enCurso) {
          viajesEnCursoCount++;
        } else if (estado == AppStates.terminado) {
          viajesTerminados++;
        }
      }

      // 5. Estadísticas de solicitudes (Distribuciones vs Recolecciones) y Totales por Producto
      final solicitudesRaw = await _client.from('solicitudes')
          .select('tipo, estado, producto, cantidad')
          .neq('estado', 'Eliminada')
          .timeout(const Duration(seconds: 15));
      
      int recoleccionesTotal = 0;
      int distribucionesTotal = 0;
      final Map<String, int> recoleccionesByState = {'Pendiente': 0, 'Asignada': 0, 'En Curso': 0, 'Terminada': 0};
      final Map<String, int> distribucionesByState = {'Pendiente': 0, 'Asignada': 0, 'En Curso': 0, 'Terminada': 0};
      final Map<String, Map<String, dynamic>> productTotals = {};

      // Mapear códigos numéricos a alfanuméricos para consolidar correctamente los productos
      final Map<String, String> numericToAlpha = {};
      final Map<String, String> productToUnit = {};
      for (var p in ProductosData.masterCatalog) {
        final numCode = p['codigo']?.toString().trim();
        final alphaCode = p['producto']?.toString().trim().toUpperCase();
        final unit = p['unidad']?.toString() ?? 'uni';
        if (numCode != null && alphaCode != null && alphaCode.isNotEmpty) {
          numericToAlpha[numCode] = alphaCode;
          productToUnit[alphaCode] = unit;
          productToUnit[numCode] = unit;
        }
      }

      for (var s in (solicitudesRaw as List)) {
        final tipo = s['tipo']?.toString().toLowerCase() ?? '';
        final estado = s['estado']?.toString() ?? 'Pendiente';
        String prod = s['producto']?.toString().toUpperCase() ?? '';
        if (numericToAlpha.containsKey(prod)) {
          prod = numericToAlpha[prod]!;
        }
        final double qty = (s['cantidad'] as num?)?.toDouble() ?? 0.0;
        final String unit = productToUnit[prod] ?? 'uni';

        // Normalizar sub-estado de solicitud
        String normEstado = 'Pendiente';
        if (estado.toLowerCase() == 'asignada' || estado.toLowerCase() == 'asignado') normEstado = 'Asignada';
        if (estado.toLowerCase() == 'en curso' || estado.toLowerCase() == 'en_curso' || estado.toLowerCase() == 'en proceso') normEstado = 'En Curso';
        if (estado.toLowerCase() == 'terminada' || estado.toLowerCase() == 'terminado') normEstado = 'Terminada';

        final bool isRecoleccion = tipo.contains('recol') || tipo.contains('rec');
        final bool isDistribucion = tipo.contains('distrib') || tipo.contains('dist');

        if (isRecoleccion) {
          recoleccionesTotal++;
          recoleccionesByState[normEstado] = (recoleccionesByState[normEstado] ?? 0) + 1;
        } else if (isDistribucion) {
          distribucionesTotal++;
          distribucionesByState[normEstado] = (distribucionesByState[normEstado] ?? 0) + 1;
        }

        // Totales por producto
        if (prod.isNotEmpty && normEstado == 'Terminada') {
          if (productTotals.containsKey(prod)) {
            productTotals[prod]!['cantidad'] = (productTotals[prod]!['cantidad'] as double) + qty;
          } else {
            productTotals[prod] = {
              'producto': prod,
              'cantidad': qty,
              'unidad': unit,
            };
          }
        }
      }

      return {
        'totalKg': totalKg,
        'viajesEnCurso': viajesEnCursoCount,
        'viajesActivos': viajesData,
        'tamboresStock': tamboresStock,
        'viajesCount': {
          'pendientes': viajesPendientes,
          'enCurso': viajesEnCursoCount,
          'terminados': viajesTerminados,
          'total': viajesAllRaw.length,
        },
        'solicitudesCount': {
          'recoleccionesTotal': recoleccionesTotal,
          'distribucionesTotal': distribucionesTotal,
          'recoleccionesByState': recoleccionesByState,
          'distribucionesByState': distribucionesByState,
        },
        'productTotals': productTotals.values.toList(),
      };
    } catch (e) {
      print('SupabaseService: Error en getGerenteStats: $e');
      return {
        'totalKg': 0.0,
        'viajesEnCurso': 0,
        'viajesActivos': [],
        'tamboresStock': 0,
        'viajesCount': {'pendientes': 0, 'enCurso': 0, 'terminados': 0, 'total': 0},
        'solicitudesCount': {
          'recoleccionesTotal': 0,
          'distribucionesTotal': 0,
          'recoleccionesByState': {'Pendiente': 0, 'Asignada': 0, 'En Curso': 0, 'Terminada': 0},
          'distribucionesByState': {'Pendiente': 0, 'Asignada': 0, 'En Curso': 0, 'Terminada': 0},
        },
        'productTotals': [],
      };
    }
  }

  // ─── SOLICITUDES / NECESIDADES ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNecesidadesPendientes() async {
    try {
      final List<dynamic> data = await _client
          .from('solicitudes')
          .select('*, apicultores(*)')
          .eq('estado', AppStates.pendiente)
          .neq('estado', 'Eliminada') // doble seguridad
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('SupabaseService: Error en getNecesidadesPendientes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllNecesidades() async {
    try {
      final List<dynamic> data = await _client
          .from('solicitudes')
          .select('*, apicultores(*)')
          .neq('estado', 'Eliminada')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('SupabaseService: Error en getAllNecesidades: $e');
      return [];
    }
  }



  // ─── CARGAS ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCargas({String? estado}) async {
    try {
      dynamic query = _client.from('cargas')
          .select('id, carga_codigo, viaje_id, estado, created_at, updated_at, carga_items(id, producto_codigo, cantidad, unidad)');
      if (estado != null) query = query.eq('estado', estado);
      final List<dynamic> data = await query
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));
      
      final List<Map<String, dynamic>> cargas = (data as List).map((c) {
        return Map<String, dynamic>.from(c as Map);
      }).toList();

      for (var c in cargas) {
        final items = c['carga_items'] as List? ?? [];
        if (items.isEmpty) {
          try {
            final directItems = await _client
                .from('carga_items')
                .select('id, producto_codigo, cantidad, unidad')
                .eq('carga_id', c['id']);
            c['carga_items'] = directItems;
          } catch (_) {}
        }
        if (c['viaje_id'] != null) {
          try {
            final viaje = await _client.from('viajes')
                .select('viaje_codigo, vehiculo_codigo, chofer_id')
                .eq('id', c['viaje_id']).maybeSingle();
            c['viaje'] = viaje;
            if (viaje?['chofer_id'] != null) {
              final chofer = await _client.from('profiles')
                  .select('nombre, apellido').eq('id', viaje!['chofer_id']).maybeSingle();
              c['chofer'] = chofer;
            }
          } catch (_) {}
        }
      }
      return cargas;
    } catch (e) {
      print('SupabaseService: Error en getCargas: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCargaDetalle(String cargaId) async {
    try {
      final res = await _client.from('cargas')
          .select('id, carga_codigo, viaje_id, estado, created_at, updated_at, carga_items(id, producto_codigo, cantidad, unidad)')
          .eq('id', cargaId).maybeSingle();
      if (res == null) return null;
      
      final Map<String, dynamic> carga = Map<String, dynamic>.from(res as Map);
      
      final items = carga['carga_items'] as List? ?? [];
      if (items.isEmpty) {
        try {
          final directItems = await _client
              .from('carga_items')
              .select('id, producto_codigo, cantidad, unidad')
              .eq('carga_id', carga['id']);
          carga['carga_items'] = directItems;
        } catch (_) {}
      }

      if (carga['viaje_id'] != null) {
        try {
          final viaje = await _client.from('viajes')
              .select('viaje_codigo, vehiculo_codigo, chofer_id, fecha')
              .eq('id', carga['viaje_id']).maybeSingle();
          carga['viaje'] = viaje;
          if (viaje?['chofer_id'] != null) {
            final chofer = await _client.from('profiles')
                .select('nombre, apellido').eq('id', viaje!['chofer_id']).maybeSingle();
            carga['chofer'] = chofer;
          }
          if (viaje?['vehiculo_codigo'] != null) {
            final vehiculo = await _client.from('vehiculos')
                .select('vehiculo_codigo, capacidad_kg, capacidad_tambores, carga_actual_kg, carga_actual_tambores')
                .eq('vehiculo_codigo', viaje!['vehiculo_codigo']).maybeSingle();
            carga['vehiculo'] = vehiculo;
          }
        } catch (_) {}
      }
      return carga;
    } catch (e) {
      print('SupabaseService: Error en getCargaDetalle: $e');
      return null;
    }
  }

  Future<String> _getCreatorId(Map<String, dynamic> viajeData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localId = prefs.getString('user_id');
      if (localId != null && localId.isNotEmpty) {
        return localId;
      }
    } catch (_) {}
    if (viajeData['chofer_id'] != null) {
      return viajeData['chofer_id'].toString();
    }
    try {
      final firstProfile = await _client.from('profiles').select('id').limit(1).maybeSingle();
      if (firstProfile != null) {
        return firstProfile['id'].toString();
      }
    } catch (_) {}
    return 'd0744e5c-3d9c-4e17-be9e-90e55f4a4c61';
  }

  Future<String> createCarga({
    required String viajeId,
    required List<Map<String, dynamic>> items,
    required String createdBy,
    String? depositoOrigen,
  }) async {
    final String cleanCreatedBy = createdBy.isNotEmpty ? createdBy : 'd0744e5c-3d9c-4e17-be9e-90e55f4a4c61';
    
    // Count existing charges to generate a human-readable consecutive code (Carga-1, Carga-2, ...)
    int count = 0;
    try {
      final list = await _client.from('cargas').select('id');
      count = list.length;
    } catch (e) {
      print('SupabaseService: Error counting charges for code generation: $e');
    }
    final String humanId = 'Carga-${count + 1}';

    final Map<String, dynamic> insertData = {
      'carga_codigo': humanId,
      'viaje_id': viajeId,
      'estado': AppStates.pendiente,
      'created_by': cleanCreatedBy,
    };
    // deposito_origen eliminado
    
    final cargaResp = await _client.from('cargas').insert(insertData).select('id').single();
    final cargaId = cargaResp['id'] as String;

    try {
      if (items.isNotEmpty) {
        final itemsToInsert = items.map((item) => {
          'carga_id': cargaId,
          'producto_codigo': item['producto_codigo'],
          'cantidad': (item['cantidad'] as num).toInt(),
          'unidad': item['unidad'] ?? 'UN',
        }).toList();
        await _client.from('carga_items').insert(itemsToInsert);
      }
      return cargaId;
    } catch (e) {
      // Rollback manual para no dejar cargas huérfanas en la base de datos
      try {
        await _client.from('cargas').delete().eq('id', cargaId);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> deleteCarga(String cargaId) async {
    await _client.from('carga_items').delete().eq('carga_id', cargaId);
    await _client.from('cargas').delete().eq('id', cargaId);
  }

  Future<void> updateCargaEstado(String cargaId, String nuevoEstado) async {
    await _client.from('cargas').update({
      'estado': nuevoEstado,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', cargaId);
    if (nuevoEstado == AppStates.terminado) {
      await _actualizarDepositoCirculante(cargaId, sumar: true);
    }
  }

  Future<void> _actualizarDepositoCirculante(String cargaId, {required bool sumar}) async {
    try {
      final carga = await _client.from('cargas')
          .select('viaje_id, carga_items(producto_codigo, cantidad)')
          .eq('id', cargaId).maybeSingle();
      if (carga == null) return;
      final viaje = await _client.from('viajes')
          .select('vehiculo_codigo').eq('id', carga['viaje_id']).maybeSingle();
      if (viaje == null) return;
      final vehiculoCodigo = viaje['vehiculo_codigo'];
      final items = List<Map<String, dynamic>>.from(carga['carga_items'] ?? []);
      double deltaKg = 0;
      int deltaTambores = 0;
      for (final item in items) {
        final rawQty = item['cantidad'];
        double qty = 0.0;
        if (rawQty != null) {
          if (rawQty is num) {
            qty = rawQty.toDouble();
          } else {
            qty = double.tryParse(rawQty.toString()) ?? 0.0;
          }
        }
        final prod = (item['producto_codigo'] ?? '').toString().toUpperCase();
        if (prod == 'TCM' || prod.contains('TAMBOR')) {
          deltaKg += qty * 300;
          deltaTambores += qty.round();
        } else if ((prod.startsWith('T') && prod != 'TV' && prod != 'TE') ||
            prod.contains('VACIO') ||
            prod.contains('VACÍO')) {
          deltaKg += qty * 20;
          deltaTambores += qty.round();
        } else if (prod == 'AZ') {
          deltaKg += qty * 50;
        } else {
          deltaKg += qty;
        }
      }
      final vehiculoData = await _client.from('vehiculos')
          .select('carga_actual_kg, carga_actual_tambores')
          .eq('vehiculo_codigo', vehiculoCodigo).maybeSingle();
      if (vehiculoData == null) return;
      final currentKg = (vehiculoData['carga_actual_kg'] as num?)?.toDouble() ?? 0;
      final currentTamb = (vehiculoData['carga_actual_tambores'] as num?)?.toInt() ?? 0;
      final sign = sumar ? 1 : -1;
      await _client.from('vehiculos').update({
        'carga_actual_kg': (currentKg + sign * deltaKg).clamp(0, double.infinity),
        'carga_actual_tambores': (currentTamb + sign * deltaTambores).clamp(0, 99999),
      }).eq('vehiculo_codigo', vehiculoCodigo);
    } catch (e) {
      print('SupabaseService: Error actualizando depósito circulante: $e');
    }
  }

  // ─── CATÁLOGOS ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getApicultores() async {
    try {
      final List<dynamic> data = await _client
          .from('apicultores')
          .select('*')
          .order('nombre', ascending: true)
          .timeout(const Duration(seconds: 8));
      final list = List<Map<String, dynamic>>.from(data);
      _auditAndFixApicultores(list);
      return list;
    } catch (e) {
      print('SupabaseService: Error en getApicultores, usando local: $e');
      // Importante: No devolvemos lista vacía si es posible, sino lo que tengamos o log local
      return []; 
    }
  }

  Future<void> _auditAndFixApicultores(List<Map<String, dynamic>> dbList) async {
    // Solo auditamos una muestra o lo hacemos de forma asíncrona controlada
    // para no sobrecargar el cliente en cada fetch.
    for (var dbApi in dbList) {
      final id = dbApi['id']?.toString() ?? '';
      final localApi = ApicultoresData.fallbackApicultores.firstWhere(
        (a) => a['apicultor_codigo'] == id,
        orElse: () => {},
      );

      if (localApi.isNotEmpty) {
        Map<String, dynamic> toUpdate = {};
        final fields = ['cuit', 'renapa', 'localidad', 'provincia', 'telefono', 'dni'];
        
        for (var f in fields) {
          final dbVal = dbApi[f]?.toString() ?? '';
          final localVal = localApi[f]?.toString() ?? '';
          
          if (localVal.isNotEmpty && dbVal.isEmpty) {
            toUpdate[f] = localVal;
          }
        }

        // Fix para swaps y truncamientos
        final dbName = dbApi['nombre']?.toString() ?? '';
        final localName = localApi['nombre']?.toString() ?? '';
        if (localName.isNotEmpty && localName.length > dbName.length + 5) {
          toUpdate['nombre'] = localName;
        }
        
        if (toUpdate.isNotEmpty) {
          updateApicultorBasicData(id, toUpdate);
        }
      }
    }
  }

  Future<void> updateApicultorBasicData(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('apicultores').update(data).eq('id', id);
    } catch (e) {
      print('SupabaseService: Error actualizando apicultor $id: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getVehiculos({bool soloDisponibles = false, String? excluirViajeId}) async {
    final list = await _fetchList('vehiculos',
        select: 'id, vehiculo_codigo, patente, modelo, capacidad_kg, capacidad_tambores, carga_actual_kg, carga_actual_tambores',
        order: 'vehiculo_codigo');

    if (soloDisponibles) {
      try {
        dynamic query = _client.from('viajes').select('vehiculo_codigo').filter('estado', 'in', ['Pendiente', 'En Proceso', 'En Curso']);
        if (excluirViajeId != null) query = query.neq('id', excluirViajeId);
        final activos = await query;
        final Set<String> ocupados = {};
        for (var v in activos) {
          if (v['vehiculo_codigo'] != null) ocupados.add(v['vehiculo_codigo'].toString());
        }
        return list.where((v) => !ocupados.contains(v['vehiculo_codigo']?.toString())).toList();
      } catch (e) {
        print('SupabaseService: Error filtrando vehículos ocupados: $e');
      }
    }
    return list;
  }

  Future<List<Map<String, dynamic>>> getChoferes({bool soloDisponibles = false, String? excluirViajeId}) async {
    final list = await _fetchList('profiles',
        select: 'id, nombre, apellido, puesto',
        filter: {'puesto': 'Chofer'});

    if (soloDisponibles) {
      try {
        dynamic query = _client.from('viajes').select('chofer_id').filter('estado', 'in', ['Pendiente', 'En Proceso', 'En Curso']);
        if (excluirViajeId != null) query = query.neq('id', excluirViajeId);
        final activos = await query;
        final Set<String> ocupados = {};
        for (var v in activos) {
          if (v['chofer_id'] != null) ocupados.add(v['chofer_id'].toString());
        }
        return list.where((c) => !ocupados.contains(c['id']?.toString())).toList();
      } catch (e) {
        print('SupabaseService: Error filtrando choferes ocupados: $e');
      }
    }
    return list;
  }



  Future<List<Map<String, dynamic>>> getProductos() async {
    try {
      final list = await _fetchList('productos',
          select: 'id, descripcion, codigo, unidad, activo',
          order: 'descripcion');
      
      // Crear un mapeo de código numérico a alfanumérico basado en masterCatalog
      final Map<String, String> numericToAlpha = {};
      for (var p in ProductosData.masterCatalog) {
        final numCode = p['codigo']?.toString().trim();
        final alphaCode = p['producto']?.toString().trim().toUpperCase();
        if (numCode != null && alphaCode != null && alphaCode.isNotEmpty) {
          numericToAlpha[numCode] = alphaCode;
        }
      }

      final dbProducts = list.where((p) => p['activo'] != false).map((p) {
        String code = p['codigo']?.toString().trim().toUpperCase() ?? '';
        if (numericToAlpha.containsKey(code)) {
          code = numericToAlpha[code]!;
        }
        return {
          'id': p['id']?.toString(),
          'codigo': code,
          'descripcion': p['descripcion']?.toString() ?? '',
          'unidad': p['unidad']?.toString() ?? 'Uni',
        };
      }).toList();

      // Mapeamos masterCatalog al mismo esquema uniforme
      final masterProducts = ProductosData.masterCatalog.map((p) => {
        'id': p['codigo']?.toString(), // Usamos el código numérico como ID temporal
        'codigo': p['producto']?.toString() ?? p['codigo']?.toString() ?? '',
        'descripcion': p['descripcion']?.toString() ?? '',
        'unidad': p['unidad']?.toString() ?? 'Uni',
      }).toList();

      // Combinar sin duplicados en el código de producto (por ejemplo, TCM, TRC)
      final Map<String, Map<String, dynamic>> combined = {};
      
      // Agregamos los del catálogo maestro primero
      for (var p in masterProducts) {
        final code = p['codigo'].toString().trim().toUpperCase();
        if (code.isNotEmpty) {
          combined[code] = p;
        }
      }
      
      // Sobreescribimos/agregamos con los de la base de datos (más actualizados)
      for (var p in dbProducts) {
        final code = p['codigo'].toString().trim().toUpperCase();
        if (code.isNotEmpty) {
          combined[code] = p;
        }
      }

      final mergedList = combined.values.toList();
      // Ordenamos por descripción
      mergedList.sort((a, b) => a['descripcion'].toString().toLowerCase().compareTo(b['descripcion'].toString().toLowerCase()));
      return mergedList;
    } catch (e) {
      print('SupabaseService: Error en getProductos: $e');
      // Fallback a catálogo maestro normalizado
      return ProductosData.masterCatalog.map((p) => {
        'id': p['codigo']?.toString(),
        'codigo': p['producto']?.toString() ?? p['codigo']?.toString() ?? '',
        'descripcion': p['descripcion']?.toString() ?? '',
        'unidad': p['unidad']?.toString() ?? 'Uni',
      }).toList();
    }
  }

  Future<List<Map<String, dynamic>>> getGastos() async {
    try {
      final List<dynamic> data = await _client.from('gastos')
          .select('*, profiles(nombre, apellido), viajes(viaje_codigo)')
          .order('fecha', ascending: false)
          .timeout(const Duration(seconds: 10));
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('SupabaseService: Error en getGastos: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRemitos() async {
    try {
      final data = await _client.from('remitos')
          .select('*, paradas(id, tipo, localidad, ubicacion, solicitud_id, parada_items(producto_codigo, cantidad))')
          .order('created_at', ascending: false);
      final remitos = List<Map<String, dynamic>>.from(data as List);
      
      // 1. Gather all unique non-null solicitud_ids
      final List<String> solIds = [];
      for (var r in remitos) {
        if (r['paradas'] != null && r['paradas']['solicitud_id'] != null) {
          final id = r['paradas']['solicitud_id'].toString();
          if (!solIds.contains(id)) {
            solIds.add(id);
          }
        }
      }

      // 2. Query all solicitudes in batch
      final Map<String, Map<String, dynamic>> solMap = {};
      if (solIds.isNotEmpty) {
        try {
          final List<dynamic> solsData = await _client.from('solicitudes')
              .select('id, apicultor_id, apicultores(nombre, localidad)')
              .filter('id', 'in', solIds);
          for (var s in solsData) {
            if (s['id'] != null) {
              solMap[s['id'].toString()] = s;
            }
          }
        } catch (se) {
          print('SupabaseService: Error in getRemitos batch solicitudes fetch: $se');
        }
      }

      for (var r in remitos) {
        // Map remito_codigo
        r['remito_codigo'] = r['numero_remito'] ?? 'REM-${r['parada_id']?.toString().split('-').first.toUpperCase()}';

        bool hasRecoleccion = false;
        bool hasDistribucion = false;

        final remitoTipo = r['tipo']?.toString().toLowerCase() ?? '';
        if (remitoTipo.contains('mixt') || remitoTipo.contains('ambos') || (remitoTipo.contains('rec') && remitoTipo.contains('dist'))) {
          hasRecoleccion = true;
          hasDistribucion = true;
        }

        if (r['paradas'] != null) {
          r['localidad'] = r['paradas']['localidad'];
          r['ubicacion'] = r['paradas']['ubicacion'];
          
          final items = r['paradas']['parada_items'] as List? ?? [];
          for (var item in items) {
            final code = (item['producto_codigo'] ?? '').toString().toUpperCase();
            if (code == 'TCM' || code.contains('MIEL')) {
              hasRecoleccion = true;
            } else {
              hasDistribucion = true;
            }
          }
          
          // Fallback if parada_items is empty, use the parada type
          if (items.isEmpty && !hasRecoleccion && !hasDistribucion) {
            final t = r['paradas']['tipo']?.toString().toLowerCase() ?? '';
            if (t.contains('mixt') || t.contains('ambos') || (t.contains('rec') && t.contains('dist'))) {
              hasRecoleccion = true;
              hasDistribucion = true;
            } else if (t.contains('recol') || t.contains('rec')) {
              hasRecoleccion = true;
            } else {
              hasDistribucion = true;
            }
          }
          
          final solId = r['paradas']['solicitud_id'];
          if (solId != null && solMap.containsKey(solId.toString())) {
            final sol = solMap[solId.toString()]!;
            if (sol['apicultores'] != null) {
              r['apicultor_nombre'] = sol['apicultores']['nombre'];
              r['apicultor_localidad'] = sol['apicultores']['localidad'];
            }
          }
        }

        // Fallbacks for apicultor
        r['apicultor_nombre'] = r['apicultor_nombre'] ?? r['ubicacion'] ?? r['persona_nombre'] ?? 'Apicultor S/D';
        r['apicultor_localidad'] = r['apicultor_localidad'] ?? r['localidad'] ?? 'Sin localidad';

        // Determine type display and category
        if (hasRecoleccion && hasDistribucion) {
          r['tipo_display'] = 'Distribución y Recolección';
          r['tipo_categoria'] = 'Mixta';
        } else if (hasRecoleccion) {
          r['tipo_display'] = 'Recolección';
          r['tipo_categoria'] = 'Recolecciones';
        } else {
          r['tipo_display'] = 'Distribución';
          r['tipo_categoria'] = 'Distribuciones';
        }
        r['tipo'] = r['tipo_display']; // For backward compatibility
      }
      return remitos;
    } catch (e) {
      print('SupabaseService: Error en getRemitos: $e');
      return [];
    }
  }

  // ─── ESCRITURA ────────────────────────────────────────────────────────────

  Future<void> createViajeCompleto({
    required Map<String, dynamic> viajeData,
    required List<Map<String, dynamic>> necesidades,
  }) async {
    final data = Map<String, dynamic>.from(viajeData);
    data['estado'] = AppStates.pendiente;
    data['fecha_planificada'] = data['fecha'] ?? DateTime.now().toIso8601String();
    data['fecha'] = data['fecha_planificada']; // Sincronizar para ordenamiento exacto

    final String humanCode = 'V-${DateFormat('ddMM').format(DateTime.now())}-${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}';
    data['viaje_codigo'] = humanCode;
    
    final viajeResp = await _client.from('viajes').insert(data).select('id, viaje_codigo').single();
    final viajeId = viajeResp['id'];
    final viajeCodigo = viajeResp['viaje_codigo'] ?? humanCode;

    // Crear Ruta inicial por defecto con manejo de errores resiliente
    dynamic rutaId;
    try {
      final rutaResp = await _client.from('rutas').insert({
        'viaje_id': viajeId,
        'ruta_codigo': 'R-$viajeCodigo-01',
        'estado': AppStates.pendiente,
        'fecha_planificada': data['fecha_planificada'],
      }).select('id').single();
      rutaId = rutaResp['id'];
    } catch (e) {
      print('SupabaseService: Error insertando ruta con codigo, reintentando simplificado: $e');
      // Reintento sin ruta_codigo por si la columna no existe o tiene RLS restrictivo
      final rutaResp = await _client.from('rutas').insert({
        'viaje_id': viajeId,
        'estado': AppStates.pendiente,
        'fecha_planificada': data['fecha_planificada'],
      }).select('id').single();
      rutaId = rutaResp['id'];
    }

    int seq = 1;
    for (final nec in necesidades) {
      final String rawTipo = (nec['tipo'] ?? 'Recolección').toString();
      final String tipoFixed = rawTipo.contains('istribu') ? 'Distribucion' : 'Recoleccion';
      final paradaResp = await _client.from('paradas').insert({
        'viaje_id': viajeId,
        'ruta_id': rutaId,
        'ubicacion': nec['apicultores']?['nombre'] ?? nec['apicultor'] ?? 'Sin Nombre',
        'tipo': tipoFixed,
        'estado': AppStates.pendiente,
        'orden_secuencia': seq++,
        'localidad': nec['apicultores']?['localidad'] ?? nec['localidad'] ?? 'S/D',
        'solicitud_id': nec['id'], // Vinculación solicitud-parada
      }).select('id').single();
      
      try {
        final String producto = nec['producto']?.toString() ?? '';
        final String lowerProd = producto.toLowerCase();
        final esUnidades = lowerProd.contains('tambor') ||
            lowerProd.contains('insumo') ||
            lowerProd.contains('alimento') ||
            lowerProd.contains('tcm') ||
            lowerProd.contains('tv');
        await _client.from('parada_items').insert({
          'parada_id': paradaResp['id'],
          'producto_codigo': producto,
          'cantidad': nec['cantidad'],
          'unidad': esUnidades ? 'UN' : 'KG',
        });
      } catch (e) { print('SupabaseService: Error en parada_item: $e'); }
      
      // Actualizar estado de las solicitudes a 'Asignada'
      try {
        final List<String> solicitudIds = necesidades
            .where((n) => n['id'] != null)
            .map((n) => n['id'].toString())
            .toList();
        if (solicitudIds.isNotEmpty) {
          await _client.from('solicitudes')
              .update({'estado': AppStates.asignada})
              .filter('id', 'in', solicitudIds);
        }
      } catch (e) {
        print('SupabaseService: Error marcando solicitudes como asignadas: $e');
      }
    }

    // Auto-generación de carga si hay distribuciones
    try {
      final dists = necesidades.where((n) {
        final tipo = (n['tipo'] ?? '').toString().toLowerCase();
        return tipo.contains('dist');
      }).toList();

      if (dists.isNotEmpty) {
        final Map<String, double> grouped = {};
        for (final n in dists) {
          final prod = (n['producto'] ?? '').toString();
          if (prod.isNotEmpty) {
            final double qty = (n['cantidad'] as num?)?.toDouble() ?? 0.0;
            grouped[prod] = (grouped[prod] ?? 0.0) + qty;
          }
        }

        if (grouped.isNotEmpty) {
          final List<Map<String, dynamic>> itemsToLoad = grouped.entries.map((e) {
            final lowerProd = e.key.toLowerCase();
            final esUnidades = lowerProd.contains('tambor') ||
                lowerProd.contains('insumo') ||
                lowerProd.contains('alimento') ||
                lowerProd.contains('tcm') ||
                lowerProd.contains('tv');
            return {
              'producto_codigo': e.key,
              'cantidad': e.value,
              'unidad': esUnidades ? 'UN' : 'KG',
            };
          }).toList();

          final creatorId = await _getCreatorId(data);
          await createCarga(
            viajeId: viajeId,
            items: itemsToLoad,
            createdBy: creatorId,
          );
        }
      }
    } catch (e) {
      print('SupabaseService: Error en auto-generacion de carga: $e');
    }
  }

  Future<void> updateViajeCompleto({
    required String viajeId,
    required Map<String, dynamic> viajeData,
    required List<Map<String, dynamic>> necesidades,
  }) async {
    await _client.from('viajes').update(viajeData).eq('id', viajeId);
    // 1. Obtener la ruta del viaje para no perder la asociación
    String? rutaId;
    try {
      final rutaResp = await _client.from('rutas')
          .select('id')
          .eq('viaje_id', viajeId)
          .order('created_at')
          .limit(1)
          .maybeSingle();
      if (rutaResp != null) {
        rutaId = rutaResp['id']?.toString();
      }
    } catch (e) {
      print('SupabaseService: Error obteniendo ruta en updateViajeCompleto: $e');
    }

    // 2. Obtener las paradas actuales para liberar sus solicitudes asociadas a 'Pendiente'
    final paradasActuales = await _client.from('paradas')
        .select('id, solicitud_id')
        .eq('viaje_id', viajeId);
    
    final List<dynamic> paradasActualesList = paradasActuales as List<dynamic>;
    final ids = paradasActualesList.map((p) => p['id']).toList();
    final List<String> oldSolicitudIds = paradasActualesList
        .where((p) => p['solicitud_id'] != null)
        .map((p) => p['solicitud_id'].toString())
        .toList();

    // 3. Resetear el estado de las solicitudes anteriores a 'Pendiente'
    if (oldSolicitudIds.isNotEmpty) {
      try {
        await _client.from('solicitudes')
            .update({'estado': AppStates.pendiente})
            .filter('id', 'in', oldSolicitudIds);
      } catch (e) {
        print('SupabaseService: Error liberando solicitudes anteriores en update: $e');
      }
    }

    if (ids.isNotEmpty) {
      await _client.from('parada_items').delete().filter('parada_id', 'in', ids);
    }
    await _client.from('paradas').delete().eq('viaje_id', viajeId);
    
    int seq = 1;
    for (final nec in necesidades) {
      final String rawTipo = (nec['tipo'] ?? 'Recolección').toString();
      final String tipoFixed = rawTipo.contains('istribu') ? 'Distribucion' : 'Recoleccion';
      
      final Map<String, dynamic> paradaInsert = {
        'viaje_id': viajeId,
        'ubicacion': nec['apicultores']?['nombre'] ?? nec['apicultor'] ?? 'Sin Nombre',
        'tipo': tipoFixed,
        'estado': AppStates.pendiente,
        'orden_secuencia': seq++,
        'localidad': nec['apicultores']?['localidad'] ?? nec['localidad'] ?? 'S/D',
        'solicitud_id': nec['id'],
      };
      if (rutaId != null) {
        paradaInsert['ruta_id'] = rutaId;
      }

      final paradaResp = await _client.from('paradas').insert(paradaInsert).select('id').single();
      try {
        final String producto = nec['producto']?.toString() ?? '';
        final String lowerProd = producto.toLowerCase();
        final esUnidades = lowerProd.contains('tambor') ||
            lowerProd.contains('insumo') ||
            lowerProd.contains('alimento') ||
            lowerProd.contains('tcm') ||
            lowerProd.contains('tv');
        await _client.from('parada_items').insert({
          'parada_id': paradaResp['id'],
          'producto_codigo': producto,
          'cantidad': nec['cantidad'],
          'unidad': esUnidades ? 'UN' : 'KG',
        });
      } catch (e) { print('SupabaseService: Error en parada_item update: $e'); }
    }
    // Actualizar estado de las solicitudes a 'Asignada'
    try {
      final List<String> solicitudIds = necesidades
          .where((n) => n['id'] != null)
          .map((n) => n['id'].toString())
          .toList();
      if (solicitudIds.isNotEmpty) {
        await _client.from('solicitudes')
            .update({'estado': AppStates.asignada})
            .filter('id', 'in', solicitudIds);
      }
    } catch (e) {
      print('SupabaseService: Error marcando solicitudes como asignadas en update: $e');
    }

    // 1. Limpiar cargas pendientes previas
    try {
      final prevCargas = await _client.from('cargas')
          .select('id')
          .eq('viaje_id', viajeId)
          .eq('estado', AppStates.pendiente);
      final List<dynamic> cargasList = prevCargas as List<dynamic>;
      if (cargasList.isNotEmpty) {
        final List<String> cargaIds = cargasList.map((c) => c['id'].toString()).toList();
        await _client.from('carga_items').delete().filter('carga_id', 'in', cargaIds);
        await _client.from('cargas').delete().filter('id', 'in', cargaIds);
      }
    } catch (e) {
      print('SupabaseService: Error eliminando cargas pendientes previas: $e');
    }

    // 2. Re-generación de carga si hay distribuciones
    try {
      final dists = necesidades.where((n) {
        final tipo = (n['tipo'] ?? '').toString().toLowerCase();
        return tipo.contains('dist');
      }).toList();

      if (dists.isNotEmpty) {
        final Map<String, double> grouped = {};
        for (final n in dists) {
          final prod = (n['producto'] ?? '').toString();
          if (prod.isNotEmpty) {
            final double qty = (n['cantidad'] as num?)?.toDouble() ?? 0.0;
            grouped[prod] = (grouped[prod] ?? 0.0) + qty;
          }
        }

        if (grouped.isNotEmpty) {
          final List<Map<String, dynamic>> itemsToLoad = grouped.entries.map((e) {
            final lowerProd = e.key.toLowerCase();
            final esUnidades = lowerProd.contains('tambor') ||
                lowerProd.contains('insumo') ||
                lowerProd.contains('alimento') ||
                lowerProd.contains('tcm') ||
                lowerProd.contains('tv');
            return {
              'producto_codigo': e.key,
              'cantidad': e.value,
              'unidad': esUnidades ? 'UN' : 'KG',
            };
          }).toList();

          final creatorId = await _getCreatorId(viajeData);
          await createCarga(
            viajeId: viajeId,
            items: itemsToLoad,
            createdBy: creatorId,
          );
        }
      }
    } catch (e) {
      print('SupabaseService: Error en re-generacion de carga en update: $e');
    }
  }

  Future<void> createNecesidad(Map<String, dynamic> data) async =>
      await _client.from('solicitudes').insert(data);

  Future<void> createPesaje(Map<String, dynamic> data) async =>
      await _client.from('pesajes').insert(data);

  Future<void> createGasto(Map<String, dynamic> data) async =>
      await _client.from('gastos').insert(data);

  Future<void> createProducto(Map<String, dynamic> data) async {
    final Map<String, dynamic> payload = Map.from(data);
    payload['activo'] = true;
    await _client.from('productos').insert(payload);
  }

  Future<void> updateProducto(String id, Map<String, dynamic> data) async {
    await _client.from('productos').update(data).eq('id', id);
  }

  Future<void> softDeleteProducto(String id) async {
    await _client.from('productos').update({'activo': false}).eq('id', id);
  }

  Future<void> createParadaItem(Map<String, dynamic> data) async =>
      await _client.from('parada_items').insert(data);

  Future<void> deleteViaje(String viajeId) async {
    try {
      // 1. Obtener las paradas para saber qué solicitudes liberar y qué items borrar
      final paradasRes = await _client.from('paradas')
          .select('id, solicitud_id')
          .eq('viaje_id', viajeId);
      
      final List<Map<String, dynamic>> paradas = List<Map<String, dynamic>>.from(paradasRes as List);
      
      final List<String> solicitudIds = [];
      final List<String> paradaIds = [];
      for (var p in paradas) {
        if (p['id'] != null) paradaIds.add(p['id'].toString());
        if (p['solicitud_id'] != null) solicitudIds.add(p['solicitud_id'].toString());
      }

      // 1.5 Borrar remitos vinculados
      if (paradaIds.isNotEmpty) {
        try {
          await _client.from('remitos').delete().inFilter('parada_id', paradaIds);
        } catch (_) {}
      }
      try {
        await _client.from('remitos').delete().eq('viaje_id', viajeId);
      } catch (_) {}

      // 2. Liberar solicitudes
      if (solicitudIds.isNotEmpty) {
        await _client.from('solicitudes')
            .update({'estado': AppStates.pendiente})
            .filter('id', 'in', solicitudIds);
      }

      // 3. Borrar paradas e items
      for (var p in paradas) {
         try {
           await _client.from('parada_items').delete().eq('parada_id', p['id']);
         } catch (_) {}
      }
      await _client.from('paradas').delete().eq('viaje_id', viajeId);
      
      // 4. Borrar cargas e items
      try {
        final cargasRes = await _client.from('cargas').select('id').eq('viaje_id', viajeId);
        final List<dynamic> cargasList = cargasRes as List;
        for (var c in cargasList) {
          await _client.from('carga_items').delete().eq('carga_id', c['id']);
        }
        await _client.from('cargas').delete().eq('viaje_id', viajeId);
      } catch (_) {}

      // 5. Borrar rutas y gastos
      await _client.from('rutas').delete().eq('viaje_id', viajeId);
      try {
        await _client.from('gastos').delete().eq('viaje_id', viajeId);
      } catch (_) {}
      
      // 6. Borrar viaje
      await _client.from('viajes').delete().eq('id', viajeId);
    } catch (e) {
      print('SupabaseService: Error eliminando viaje: $e');
      throw 'No se pudo eliminar el viaje: $e';
    }
  }

  Future<void> deleteSolicitud(String id) async {
    try {
      // Realizar borrado lógico cambiando el estado de la solicitud a 'Eliminada'
      await _client.from('solicitudes').update({'estado': 'Eliminada'}).eq('id', id);
    } catch (e) {
      print('SupabaseService: Error en borrado lógico de solicitud: $e');
      throw 'No se pudo eliminar la solicitud: $e';
    }
  }

  Future<void> updateSolicitud(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('solicitudes').update(data).eq('id', id);
    } catch (e) {
      print('SupabaseService: Error actualizando solicitud: $e');
      throw 'No se pudo actualizar la solicitud: $e';
    }
  }

  // ─── HELPER PRIVADO ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchList(String table, {
    required String select,
    Map<String, String>? filter,
    String? order,
  }) async {
    try {
      dynamic query = _client.from(table).select(select);
      if (filter != null) {
        filter.forEach((key, value) { query = query.eq(key, value); });
      }
      if (order != null) query = query.order(order, ascending: false);
      final data = await query.timeout(const Duration(seconds: 10));
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      print('SupabaseService: Error listando $table: $e');
      return [];
    }
  }

  Future<void> deleteParadaItem(String itemId) async {
    await _client.from('parada_items').delete().eq('id', itemId);
  }

  /// Elimina un remito y restablece la parada a editable (solo para admin).
  Future<void> deleteRemito(String remitoId, String paradaId) async {
    try {
      // Eliminar el remito
      await _client.from('remitos').delete().eq('id', remitoId);
      // Resetear la parada: quitar remito_id y volver a En Proceso para que se pueda regenerar
      await _client.from('paradas').update({
        'remito_id': null,
        'estado': AppStates.enCurso,
      }).eq('id', paradaId);
    } catch (e) {
      print('SupabaseService: Error eliminando remito: $e');
      throw 'No se pudo eliminar el remito: $e';
    }
  }

  Future<void> finalizarParada(String paradaId, String vehiculoCodigo) async {
    try {
      // 1. Obtener datos de la parada y sus items actuales (incluyendo unidad para saber la operación)
      final parada = await _client.from('paradas')
          .select('id, tipo, solicitud_id, parada_items(producto_codigo, cantidad, unidad)')
          .eq('id', paradaId)
          .maybeSingle();
      
      if (parada == null) throw Exception('Parada no encontrada');
      
      final String tipo = (parada['tipo'] ?? 'Recoleccion').toString();
      final items = List<Map<String, dynamic>>.from(parada['parada_items'] ?? []);
      
      // 2. Calcular impacto neto en el peso y tambores
      double netKgChange = 0;
      int netTamboresChange = 0;
      
      for (final item in items) {
        final double qty = (item['cantidad'] as num?)?.toDouble() ?? 0;
        final String prod = (item['producto_codigo'] ?? '').toString().toUpperCase();
        
        // Determinar tipo de operación del ítem
        final String unitRaw = (item['unidad'] ?? '').toString();
        final parts = unitRaw.split('|');
        final String itemOpType = parts.length > 1 ? parts[1] : tipo; // fallback al tipo de parada
        
        // Si es Recolección, es un cambio positivo para el camión (+).
        // Si es Distribución, es un cambio negativo (-).
        final bool isItemRecoleccion = itemOpType.toLowerCase().contains('recolec') || itemOpType.toLowerCase().contains('retiro');
        final double sign = isItemRecoleccion ? 1.0 : -1.0;
        
        double itemKg = 0;
        int itemTambores = 0;

        // Lógica de pesos (Constantes de negocio)
        if (prod == 'TCM') {
          itemKg = qty * 300;
          itemTambores = qty.round();
        } else if (prod.startsWith('T') && (prod.contains('V') || prod.contains('N') || prod.contains('R'))) {
          // Tambores vacíos o nuevos
          itemKg = qty * 20;
          itemTambores = qty.round();
        } else if (prod == 'AZ') {
          itemKg = qty * 50; // Bolsa x 50kg
        } else {
          itemKg = qty; // Por defecto 1kg por unidad si no es tambor/bolsa
        }

        netKgChange += sign * itemKg;
        netTamboresChange += (sign * itemTambores).round();
      }

      // 3. Actualizar Vehículo
      final vehiculoData = await _client.from('vehiculos')
          .select('carga_actual_kg, carga_actual_tambores')
          .eq('vehiculo_codigo', vehiculoCodigo)
          .maybeSingle();
          
      if (vehiculoData != null) {
        final double currentKg = (vehiculoData['carga_actual_kg'] as num?)?.toDouble() ?? 0;
        final int currentTamb = (vehiculoData['carga_actual_tambores'] as num?)?.toInt() ?? 0;
        
        await _client.from('vehiculos').update({
          'carga_actual_kg': (currentKg + netKgChange).clamp(0.0, 999999.0),
          'carga_actual_tambores': (currentTamb + netTamboresChange).clamp(0, 999),
        }).eq('vehiculo_codigo', vehiculoCodigo);
      }

      // 4. Actualizar Estados
      await _client.from('paradas').update({'estado': AppStates.terminado}).eq('id', paradaId);
      
      final String? solId = parada['solicitud_id']?.toString();
      if (solId != null) {
        await _client.from('solicitudes').update({'estado': 'Terminada'}).eq('id', solId);
      }
      
    } catch (e) {
      print('SupabaseService: Error en finalizarParada: $e');
      throw e;
    }
  }
}
