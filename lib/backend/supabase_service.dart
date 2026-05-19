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
        var query = _client.from('viajes').select('*, paradas(*)');

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
    try {
      final viaje = await _client.from('viajes')
          .select('id, viaje_codigo, vehiculo_codigo, chofer_id, estado, fecha, fecha_planificada, fecha_inicio, fecha_terminado, descripcion')
          .eq('id', viajeId).maybeSingle();
      if (viaje == null) return null;
      viaje['estado'] = AppStates.normalize(viaje['estado']);
      if (viaje['chofer_id'] != null) {
        try {
          final chofer = await _client.from('profiles')
              .select('nombre, apellido').eq('id', viaje['chofer_id']).maybeSingle();
          viaje['chofer'] = chofer;
        } catch (_) {}
      }
      try {
        final rutas = await _client.from('rutas')
            .select('*, paradas(*, parada_items(*), remitos(*))')
            .eq('viaje_id', viajeId).order('created_at');
        viaje['rutas_data'] = rutas;
        
        // Mantener paradas en raíz para compatibilidad legacy, pero vinculadas a sus rutas
        final List<dynamic> allParadas = [];
        for (var r in rutas) {
          final pList = List<Map<String, dynamic>>.from(r['paradas'] ?? []);
          for (var p in pList) p['ruta_codigo'] = r['ruta_codigo'];
          allParadas.addAll(pList);
        }
        viaje['paradas'] = allParadas..sort((a, b) => (a['orden_secuencia'] ?? 0).compareTo(b['orden_secuencia'] ?? 0));
      } catch (_) { 
        // Fallback a paradas directas si no hay rutas aún
        final paradas = await _client.from('paradas')
            .select('id, viaje_id, solicitud_id, orden_secuencia, tipo, ubicacion, localidad, estado, remito_id, parada_items(id, producto_codigo, cantidad, unidad), remitos(*)')
            .eq('viaje_id', viajeId).order('orden_secuencia');
        viaje['paradas'] = paradas;
      }
      try {
        final gastos = await _client.from('gastos')
            .select('id, categoria, monto, fecha, comprobante_url')
            .eq('viaje_id', viajeId).order('fecha');
        viaje['gastos'] = gastos;
      } catch (_) { viaje['gastos'] = []; }

      try {
        final cargas = await _client.from('cargas')
            .select('*, carga_items(*)')
            .eq('viaje_id', viajeId).order('created_at');
        viaje['cargas'] = cargas;
      } catch (_) { viaje['cargas'] = []; }

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

  /// Marca todas las cargas de un viaje como 'Terminado' (Cargado físicamente)
  Future<void> confirmarCargaViaje(String viajeId) async {
    final List<dynamic> cargas = await _client.from('cargas')
        .select('id')
        .eq('viaje_id', viajeId)
        .eq('estado', AppStates.pendiente);
    
    for (var c in cargas) {
      await updateCargaEstado(c['id'].toString(), AppStates.terminado);
    }
  }

  Future<List<Map<String, dynamic>>> getTerminatedCargas() async {
    final res = await _client.from('cargas')
        .select('*, viaje:viaje_id(*, profiles(nombre, apellido), vehiculo:vehiculo_codigo(*)), carga_items(*)')
        .eq('estado', AppStates.terminado)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
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

  Future<Map<String, dynamic>> getGerenteStats() async {
    try {
      final paradasData = await _client.from('paradas')
          .select('carga_kg').not('carga_kg', 'is', null).timeout(const Duration(seconds: 10));
      double totalKg = (paradasData as List).fold(0.0, (sum, p) => sum + ((p['carga_kg'] as num?)?.toDouble() ?? 0));
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
      final pesajesData = await _client.from('pesajes').select('id').timeout(const Duration(seconds: 10));
      return {
        'totalKg': totalKg,
        'viajesEnCurso': viajesData.length,
        'viajesActivos': viajesData,
        'tamboresStock': (pesajesData as List).length,
      };
    } catch (e) {
      return {'totalKg': 0.0, 'viajesEnCurso': 0, 'viajesActivos': [], 'tamboresStock': 0};
    }
  }

  // ─── SOLICITUDES / NECESIDADES ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNecesidadesPendientes() async {
    try {
      final List<dynamic> data = await _client
          .from('solicitudes')
          .select('*, apicultores(*)')
          .eq('estado', AppStates.pendiente)
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
      final cargas = List<Map<String, dynamic>>.from(data);
      for (var c in cargas) {
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
      final carga = await _client.from('cargas')
          .select('id, carga_codigo, viaje_id, estado, created_at, updated_at, carga_items(id, producto_codigo, cantidad, unidad)')
          .eq('id', cargaId).maybeSingle();
      if (carga == null) return null;
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

  Future<String> createCarga({
    required String viajeId,
    required List<Map<String, dynamic>> items,
    required String createdBy,
  }) async {
    final cargaResp = await _client.from('cargas').insert({
      'carga_codigo': 'CARGA-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      'viaje_id': viajeId,
      'estado': AppStates.pendiente,
      'created_by': createdBy,
    }).select('id').single();
    final cargaId = cargaResp['id'] as String;
    for (final item in items) {
      await _client.from('carga_items').insert({
        'carga_id': cargaId,
        'producto_codigo': item['producto_codigo'],
        'cantidad': item['cantidad'],
        'unidad': item['unidad'] ?? 'UN',
      });
    }
    return cargaId;
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
        final qty = (item['cantidad'] as num).toDouble();
        final prod = (item['producto_codigo'] ?? '').toString().toLowerCase();
        if (prod.contains('tcm') || prod.contains('tambor')) {
          deltaKg += qty * 300;
          deltaTambores += qty.round();
        } else if (prod.contains('tv') || prod.contains('vacio') || prod.contains('vacío')) {
          deltaKg += qty * 20;
          deltaTambores += qty.round();
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

  Future<List<Map<String, dynamic>>> getVehiculos() async =>
      _fetchList('vehiculos',
          select: 'id, vehiculo_codigo, patente, modelo, capacidad_kg, capacidad_tambores, carga_actual_kg, carga_actual_tambores',
          order: 'vehiculo_codigo');

  Future<List<Map<String, dynamic>>> getChoferes() async =>
      _fetchList('profiles',
          select: 'id, nombre, apellido, puesto',
          filter: {'puesto': 'Chofer'});



  Future<List<Map<String, dynamic>>> getProductos() async {
    try {
      final list = await _fetchList('productos',
          select: 'id, descripcion, codigo, unidad, activo',
          order: 'descripcion');
      
      final dbProducts = list.where((p) => p['activo'] != false).map((p) => {
        'id': p['id']?.toString(),
        'codigo': p['codigo']?.toString() ?? '',
        'descripcion': p['descripcion']?.toString() ?? '',
        'unidad': p['unidad']?.toString() ?? 'Uni',
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
  }

  Future<void> updateViajeCompleto({
    required String viajeId,
    required Map<String, dynamic> viajeData,
    required List<Map<String, dynamic>> necesidades,
  }) async {
    await _client.from('viajes').update(viajeData).eq('id', viajeId);
    final paradasActuales = await _client.from('paradas').select('id').eq('viaje_id', viajeId);
    final ids = (paradasActuales as List).map((p) => p['id']).toList();
    if (ids.isNotEmpty) {
      await _client.from('parada_items').delete().filter('parada_id', 'in', ids);
    }
    await _client.from('paradas').delete().eq('viaje_id', viajeId);
    int seq = 1;
    for (final nec in necesidades) {
      final paradaResp = await _client.from('paradas').insert({
        'viaje_id': viajeId,
        'ubicacion': nec['apicultores']?['nombre'] ?? nec['apicultor'] ?? 'Sin Nombre',
        'tipo': nec['tipo'] ?? 'Operación',
        'estado': AppStates.pendiente,
        'orden_secuencia': seq++,
        'localidad': nec['apicultores']?['localidad'] ?? nec['localidad'] ?? 'S/D',
        'solicitud_id': nec['id'],
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
      for (var p in paradas) {
        if (p['solicitud_id'] != null) solicitudIds.add(p['solicitud_id'].toString());
      }

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
      await _client.from('solicitudes').delete().eq('id', id);
    } catch (e) {
      print('SupabaseService: Error eliminando solicitud: $e');
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

  Future<void> finalizarParada(String paradaId, String vehiculoCodigo) async {
    try {
      // 1. Obtener datos de la parada y sus items actuales
      final parada = await _client.from('paradas')
          .select('id, tipo, solicitud_id, parada_items(producto_codigo, cantidad)')
          .eq('id', paradaId)
          .maybeSingle();
      
      if (parada == null) throw Exception('Parada no encontrada');
      
      final String tipo = (parada['tipo'] ?? 'Recoleccion').toString();
      final bool esRecoleccion = tipo.toLowerCase().contains('recolec');
      final items = List<Map<String, dynamic>>.from(parada['parada_items'] ?? []);
      
      // 2. Calcular impacto en el peso y tambores
      double deltaKg = 0;
      int deltaTambores = 0;
      
      for (final item in items) {
        final double qty = (item['cantidad'] as num?)?.toDouble() ?? 0;
        final String prod = (item['producto_codigo'] ?? '').toString().toUpperCase();
        
        // Lógica de pesos (Constantes de negocio)
        if (prod == 'TCM') {
          deltaKg += qty * 300;
          deltaTambores += qty.round();
        } else if (prod.startsWith('T') && (prod.contains('V') || prod.contains('N') || prod.contains('R'))) {
          // Tambores vacíos o nuevos
          deltaKg += qty * 20;
          deltaTambores += qty.round();
        } else if (prod == 'AZ') {
          deltaKg += qty * 50; // Bolsa x 50kg
        } else {
          deltaKg += qty; // Por defecto 1kg por unidad si no es tambor/bolsa
        }
      }

      // 3. Actualizar Vehículo
      final vehiculoData = await _client.from('vehiculos')
          .select('carga_actual_kg, carga_actual_tambores')
          .eq('vehiculo_codigo', vehiculoCodigo)
          .maybeSingle();
          
      if (vehiculoData != null) {
        final double currentKg = (vehiculoData['carga_actual_kg'] as num?)?.toDouble() ?? 0;
        final int currentTamb = (vehiculoData['carga_actual_tambores'] as num?)?.toInt() ?? 0;
        
        // Si es Recolección, SUMA al camión. Si es Distribución, RESTA.
        final int sign = esRecoleccion ? 1 : -1;
        
        await _client.from('vehiculos').update({
          'carga_actual_kg': (currentKg + sign * deltaKg).clamp(0, 999999),
          'carga_actual_tambores': (currentTamb + sign * deltaTambores).clamp(0, 999),
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
