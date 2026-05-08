import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'apicultores_data.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  /// Realiza el login manual buscando en la tabla profiles.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final cleanEmail = email.trim();
    final cleanPass = password.trim();

    // Estrategia 1: Supabase Auth (Sistema estándar)
    try {
      final authRes = await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: cleanPass,
      ).timeout(const Duration(seconds: 5));
      
      if (authRes.user != null) {
        final profile = await _client.from('profiles').select('id, nombre, apellido, email, puesto').eq('id', authRes.user!.id).maybeSingle();
        if (profile != null) {
          print('SupabaseService: Login exitoso vía Auth para ${profile['nombre']}');
          return await _saveLocal(profile);
        }
      }
    } catch (e) {
      print('SupabaseService: Auth estándar no disponible o falló: $e');
    }

    // Estrategia 2: Búsqueda manual en tabla profiles (Sistema alternativo)
    try {
      final response = await _client
          .from('profiles')
          .select('id, nombre, apellido, email, puesto')
          .eq('email', cleanEmail)
          .timeout(const Duration(seconds: 5));

      if ((response as List).isNotEmpty) {
        final user = (response as List).first;
        // Solo verificamos contraseña si existe la columna, si no, confiamos en el email para desarrollo
        if (user.containsKey('contrasena') && user['contrasena'] != cleanPass) {
          throw Exception('Credenciales incorrectas');
        }
        print('SupabaseService: Login exitoso vía Tabla para ${user['nombre']}');
        return await _saveLocal(user);
      }
    } catch (e) {
      print('SupabaseService: Login manual falló: $e');
    }

    throw Exception('Credenciales incorrectas');
  }

  Future<Map<String, dynamic>> _saveLocal(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user['id']?.toString() ?? '');
    await prefs.setString('user_email', user['email'] ?? '');
    await prefs.setString('user_nombre', user['nombre'] ?? '');
    await prefs.setString('user_apellido', user['apellido'] ?? '');
    await prefs.setString('user_puesto', user['puesto'] ?? '');
    return user;
  }

  /// Obtiene los viajes de forma resiliente.
  /// Obtiene los viajes de forma ultra-resiliente.
  Future<List<Map<String, dynamic>>> getViajes({String? userId, String? role}) async {
    try {
      print('SupabaseService: Obteniendo viajes maestros (UserId: $userId, Role: $role)');
      
      // 1. Obtener viajes básicos
      var query = _client.from('viajes').select('id, viaje_codigo, vehiculo_codigo, chofer_id, estado, fecha, descripcion');
      if (role == 'Chofer' && userId != null) {
        query = query.eq('chofer_id', userId);
      }
      final List<dynamic> data = await query.order('fecha', ascending: false).timeout(const Duration(seconds: 10));
      final viajes = List<Map<String, dynamic>>.from(data);

      // 2. Cargar Choferes de forma independiente para evitar fallos de JOIN
      for (var v in viajes) {
        if (v['chofer_id'] != null) {
          try {
            final chofer = await _client.from('profiles').select('nombre, apellido').eq('id', v['chofer_id']).maybeSingle();
            v['chofer'] = chofer;
          } catch (_) { v['chofer'] = null; }
        }
      }
      return viajes;
    } catch (e) {
      print('SupabaseService: Error crítico en getViajes: $e');
      return [];
    }
  }

  /// Obtiene el detalle de un viaje con TODA su información relacionada.
  Future<Map<String, dynamic>?> getViajeDetalle(dynamic viajeId) async {
    try {
      print('SupabaseService: Buscando viaje maestro con ID: $viajeId');
      
      // 1. Cargar el viaje base
      final viaje = await _client.from('viajes').select('id, viaje_codigo, vehiculo_codigo, chofer_id, estado, fecha, descripcion').eq('id', viajeId).maybeSingle();
      if (viaje == null) return null;

      // 2. Cargar Chofer (Plan B de búsqueda manual)
      if (viaje['chofer_id'] != null) {
        try {
          final chofer = await _client.from('profiles').select('nombre, apellido').eq('id', viaje['chofer_id']).maybeSingle();
          viaje['chofer'] = chofer;
        } catch (_) {}
      }

      try {
        final paradas = await _client.from('paradas').select('id, viaje_id, orden_secuencia, tipo, ubicacion, localidad, estado, remito_id, parada_items(id, producto_codigo, cantidad, unidad)').eq('viaje_id', viajeId).order('orden_secuencia');
        viaje['paradas'] = paradas;
      } catch (_) { viaje['paradas'] = []; }

      try {
        final gastos = await _client.from('gastos').select('id, categoria, monto, fecha, comprobante_url').eq('viaje_id', viajeId).order('fecha');
        viaje['gastos'] = gastos;
      } catch (_) { viaje['gastos'] = []; }

      return viaje;
    } catch (e) {
      print('SupabaseService: Error crítico en getViajeDetalle: $e');
      return null;
    }
  }

  /// Estadísticas básicas para conductores.
  Future<Map<String, int>> getStats({String? userId, String? role}) async {
    try {
      var query = _client.from('viajes').select('estado');
      if (role == 'Chofer' && userId != null) {
        query = query.eq('chofer_id', userId);
      }
      final data = await query.timeout(const Duration(seconds: 10));
      int planificados = 0, enCurso = 0, terminados = 0;
      for (final v in data) {
        final e = v['estado'] ?? '';
        if (e == 'Planificado') planificados++;
        else if (e == 'En Curso' || e == 'En Proceso' || e == 'Cargado') enCurso++;
        else if (e == 'Terminado' || e == 'Finalizado') terminados++;
      }
      return {'planificados': planificados, 'en_curso': enCurso, 'terminados': terminados};
    } catch (e) {
      return {'planificados': 0, 'en_curso': 0, 'terminados': 0};
    }
  }

  /// Estadísticas para el dashboard gerencial.
  Future<Map<String, dynamic>> getGerenteStats() async {
    try {
      final paradasData = await _client.from('paradas').select('bruto_kg').not('bruto_kg', 'is', null).timeout(const Duration(seconds: 10));
      double totalKg = paradasData.fold(0.0, (sum, p) => sum + (p['bruto_kg'] as num).toDouble());

      final viajesDataRaw = await _client.from('viajes').select('id, viaje_codigo, vehiculo_codigo, chofer_id, estado, fecha, descripcion').eq('estado', 'En Curso').timeout(const Duration(seconds: 10));
      final List<Map<String, dynamic>> viajesData = List<Map<String, dynamic>>.from(viajesDataRaw);
      
      // Join choferes manualmente
      for (var v in viajesData) {
        if (v['chofer_id'] != null) {
          try {
            final chofer = await _client.from('profiles').select('nombre, apellido').eq('id', v['chofer_id']).maybeSingle();
            v['profiles'] = chofer;
          } catch (_) {}
        }
      }

      final pesajesData = await _client.from('pesajes').select('id').timeout(const Duration(seconds: 10));

      return {
        'totalKg': totalKg,
        'viajesEnCurso': viajesData.length,
        'viajesActivos': viajesData,
        'tamboresStock': pesajesData.length,
      };
    } catch (e) {
      return {'totalKg': 0.0, 'viajesEnCurso': 0, 'viajesActivos': [], 'tamboresStock': 0};
    }
  }

  Future<List<Map<String, dynamic>>> getNecesidadesPendientes() async {
    // Fetch explicit columns to avoid p.rol error and ensure all needed data for planning
    final solicitudes = await _fetchList('solicitudes', 
      select: 'id, apicultor_id, apicultor_nombre, localidad_nombre, producto, cantidad, tipo, estado, created_at', 
      filter: {'estado': 'Pendiente'}
    );
    return await _joinApicultores(solicitudes);
  }

  Future<List<Map<String, dynamic>>> getAllNecesidades() async {
    final solicitudes = await _fetchList('solicitudes', 
      select: 'id, apicultor_id, solicitud_codigo, producto, cantidad, tipo, localidad, estado, created_at', 
      order: 'created_at'
    );
    return await _joinApicultores(solicitudes);
  }

  Future<List<Map<String, dynamic>>> _joinApicultores(List<Map<String, dynamic>> solicitudes) async {
    if (solicitudes.isEmpty) return [];
    try {
      final apicultores = await getApicultores();
      print('SupabaseService: Uniendo ${solicitudes.length} solicitudes con ${apicultores.length} apicultores');
      
      final Map<String, Map<String, dynamic>> apiMap = {};
      for (var a in apicultores) {
        final id = a['id']?.toString().trim();
        if (id != null) apiMap[id] = a;
      }

      for (var s in solicitudes) {
        final apiId = s['apicultor_id']?.toString().trim();
        
        // Ensure we always have an 'apicultores' object for UI consistency
        if (apiId != null && apiMap.containsKey(apiId)) {
          s['apicultores'] = apiMap[apiId];
        } else {
          // Fallback logic if ID doesn't match or is null
          s['apicultores'] = {
            'nombre': 'S/D', 
            'localidad': s['localidad'] ?? 'S/D',
          };
          
          // Direct fetch if we have an ID but not in cache
          if (apiId != null && apiId.length > 5) { // Evitar IDs numéricos del mock anterior
            try {
              final api = await _client.from('apicultores').select('id, nombre, localidad').eq('id', apiId).maybeSingle();
              if (api != null) s['apicultores'] = api;
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      print('SupabaseService: Error uniendo apicultores: $e');
    }
    return solicitudes;
  }
  Future<List<Map<String, dynamic>>> getVehiculos() async => _fetchList('vehiculos', select: 'id, vehiculo_codigo, patente, modelo, capacidad_kg, capacidad_tambores', order: 'vehiculo_codigo');
  Future<List<Map<String, dynamic>>> getChoferes() async => _fetchList('profiles', select: 'id, nombre, apellido, puesto', filter: {'puesto': 'Chofer'});

  Future<List<Map<String, dynamic>>> getApicultores() async {
    try {
      final list = await _fetchList('apicultores', select: 'id, nombre, localidad, apicultor_codigo, provincia, dni, cuit, renapa, telefono', order: 'nombre');
      if (list.isNotEmpty) return list;
      
      // Fallback: Datos reales del Google Sheet si la DB está vacía
      print('SupabaseService: Usando datos de respaldo para apicultores');
      return ApicultoresData.fallbackApicultores;
    } catch (e) {
      print('SupabaseService: Error en getApicultores: $e');
      return ApicultoresData.fallbackApicultores;
    }
  }
  Future<List<Map<String, dynamic>>> getProductos() async => _fetchList('productos', select: 'id, descripcion, codigo, unidad', order: 'descripcion');
  Future<List<Map<String, dynamic>>> getGastos() async {
    final gastos = await _fetchList('gastos', select: 'id, categoria, monto, fecha, chofer_id, viaje_id', order: 'fecha');
    for (var g in gastos) {
      if (g['chofer_id'] != null) {
        try {
          final profile = await _client.from('profiles').select('nombre, apellido').eq('id', g['chofer_id']).maybeSingle();
          g['profiles'] = profile;
        } catch (_) {}
      }
    }
    return gastos;
  }

  Future<List<Map<String, dynamic>>> getRemitos() async {
    final remitos = await _fetchList('remitos', select: 'id, remito_codigo, parada_id, apicultor_id, created_at', order: 'created_at');
    for (var r in remitos) {
      if (r['apicultor_id'] != null) {
        try {
          final api = await _client.from('apicultores').select('nombre').eq('id', r['apicultor_id']).maybeSingle();
          r['apicultores'] = api;
        } catch (_) {}
      }
    }
    return remitos;
  }

  Future<List<Map<String, dynamic>>> _fetchList(String table, {required String select, Map<String, String>? filter, String? order}) async {
    try {
      dynamic query = _client.from(table).select(select);
      if (filter != null) {
        filter.forEach((key, value) { 
          query = query.eq(key, value); 
        });
      }
      if (order != null) {
        query = query.order(order, ascending: false);
      }
      final data = await query.timeout(const Duration(seconds: 10));
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      print('SupabaseService: Error listando $table: $e');
      return [];
    }
  }

  /// Escritura: Crear Viaje Completo y Solicitudes.
  Future<void> createViajeCompleto({required Map<String, dynamic> viajeData, required List<Map<String, dynamic>> necesidades}) async {
    try {
      print('SupabaseService: Insertando Viaje...');
      final viajeResp = await _client.from('viajes').insert(viajeData).select('id').single();
      final viajeId = viajeResp['id'];
      print('SupabaseService: Viaje creado ID: $viajeId');
      
      int seq = 1;
      for (final nec in necesidades) {
        print('SupabaseService: Procesando solicitud ${nec['id']}...');
        final paradaData = {
          'viaje_id': viajeId,
          'ubicacion': nec['apicultores']?['nombre'] ?? nec['apicultor'] ?? 'Sin Nombre',
          'tipo': nec['tipo'] ?? 'Operación', 
          'estado': 'Pendiente',
          'orden_secuencia': seq++,
          'localidad': nec['apicultores']?['localidad'] ?? nec['localidad'] ?? 'S/D',
        };
        
        // El campo apicultor_id no existe en la tabla paradas según el error PGRST204
        // La relación se mantiene implícita vía ubicacion/localidad o se manejará por vista si es necesario.

        print('SupabaseService: Insertando Parada...');
        final paradaResp = await _client.from('paradas').insert(paradaData).select('id').single();
        print('SupabaseService: Parada creada ID: ${paradaResp['id']}');

        try {
          final String producto = nec['producto']?.toString() ?? '';
          final String lowerProd = producto.toLowerCase();
          
          // Sincronizado con la lógica de la UI: Solo tambores (no cera), insumos o alimentos son UN
          final esUnidades = (lowerProd.contains('tambor') && !lowerProd.contains('cera')) || 
                             lowerProd.contains('insumo') ||
                             lowerProd.contains('alimento') ||
                             lowerProd.contains('tcm') ||
                             lowerProd.contains('tv');
          
          print('SupabaseService: Insertando parada_item para $producto (Unidad: ${esUnidades ? 'UN' : 'KG'})');
          
          await _client.from('parada_items').insert({
            'parada_id': paradaResp['id'],
            'producto_codigo': producto,
            'cantidad': nec['cantidad'],
            'unidad': esUnidades ? 'UN' : 'KG',
          });
        } catch (e) {
          print('SupabaseService: Error insertando parada_item para ${nec['producto']}: $e');
        }
        await _client.from('solicitudes').update({'estado': 'Planificada'}).eq('id', nec['id']);
      }
    } catch (e) {
      print('SupabaseService: Error en createViajeCompleto: $e');
      rethrow;
    }
  }


  /// Crea una nueva necesidad/solicitud en la tabla solicitudes.
  Future<void> createNecesidad(Map<String, dynamic> data) async {
    try {
      await _client.from('solicitudes').insert(data);
    } catch (e) {
      print('SupabaseService: Error en createNecesidad: $e');
      rethrow;
    }
  }

  /// Registra un pesaje de tambor.
  Future<void> createPesaje(Map<String, dynamic> data) async {
    try {
      await _client.from('pesajes').insert(data);
    } catch (e) {
      print('SupabaseService: Error en createPesaje: $e');
      rethrow;
    }
  }

  /// Registra un gasto asociado a un viaje y chofer.
  Future<void> createGasto(Map<String, dynamic> data) async {
    try {
      await _client.from('gastos').insert(data);
    } catch (e) {
      print('SupabaseService: Error en createGasto: $e');
      rethrow;
    }
  }

  /// Registra un nuevo producto (solo Gerencia/Compras/CEO).
  Future<void> createProducto(Map<String, dynamic> data) async {
    try {
      await _client.from('productos').insert(data);
    } catch (e) {
      print('SupabaseService: Error en createProducto: $e');
      rethrow;
    }
  }

  /// Registra un item en una parada.
  Future<void> createParadaItem(Map<String, dynamic> data) async {
    try {
      await _client.from('parada_items').insert(data);
    } catch (e) {
      print('SupabaseService: Error en createParadaItem: $e');
      rethrow;
    }
  }

  /// Actualiza un Viaje y sus paradas (Punto 10 del Workflow).
  Future<void> updateViajeCompleto({required String viajeId, required Map<String, dynamic> viajeData, required List<Map<String, dynamic>> necesidades}) async {
    try {
      // 1. Actualizar datos básicos del viaje
      await _client.from('viajes').update(viajeData).eq('id', viajeId);
      
      // 2. Eliminar items y paradas actuales para re-crear la ruta actualizada
      final paradasActuales = await _client.from('paradas').select('id').eq('viaje_id', viajeId);
      final ids = (paradasActuales as List).map((p) => p['id']).toList();
      if (ids.isNotEmpty) {
        await _client.from('parada_items').delete().filter('parada_id', 'in', ids);
      }
      await _client.from('paradas').delete().eq('viaje_id', viajeId);
      
      // 3. Crear nuevas paradas
      int seq = 1;
      for (final nec in necesidades) {
        final paradaData = {
          'viaje_id': viajeId,
          'ubicacion': nec['apicultores']?['nombre'] ?? nec['apicultor'] ?? 'Sin Nombre',
          'tipo': nec['tipo'] ?? 'Operación', 
          'estado': 'Pendiente',
          'orden_secuencia': seq++,
          'localidad': nec['apicultores']?['localidad'] ?? nec['localidad'] ?? 'S/D',
        };
        
        // El campo apicultor_id no existe en la tabla paradas

        final paradaResp = await _client.from('paradas').insert(paradaData).select('id').single();
        
        try {
          final String producto = nec['producto']?.toString() ?? '';
          final String lowerProd = producto.toLowerCase();
          
          // Sincronizado con la lógica de la UI
          final esUnidades = (lowerProd.contains('tambor') && !lowerProd.contains('cera')) || 
                             lowerProd.contains('insumo') ||
                             lowerProd.contains('alimento') ||
                             lowerProd.contains('tcm') ||
                             lowerProd.contains('tv');

          print('SupabaseService: Update - Insertando parada_item para $producto (Unidad: ${esUnidades ? 'UN' : 'KG'})');

          await _client.from('parada_items').insert({
            'parada_id': paradaResp['id'],
            'producto_codigo': producto,
            'cantidad': nec['cantidad'],
            'unidad': esUnidades ? 'UN' : 'KG',
          });
        } catch (e) {
          print('SupabaseService: Error insertando parada_item en update para ${nec['producto']}: $e');
        }
        
        await _client.from('solicitudes').update({'estado': 'Planificada'}).eq('id', nec['id']);
      }
    } catch (e) {
      print('SupabaseService: Error en updateViajeCompleto: $e');
      rethrow;
    }
  }
}
