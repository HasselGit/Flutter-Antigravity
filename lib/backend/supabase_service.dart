import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        final profile = await _client.from('profiles').select().eq('id', authRes.user!.id).maybeSingle();
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
          .select()
          .eq('email', cleanEmail)
          .timeout(const Duration(seconds: 5));

      if (response != null && (response as List).isNotEmpty) {
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
      var query = _client.from('viajes').select();
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
      final viaje = await _client.from('viajes').select().eq('id', viajeId).maybeSingle();
      if (viaje == null) return null;

      // 2. Cargar Chofer (Plan B de búsqueda manual)
      if (viaje['chofer_id'] != null) {
        try {
          final chofer = await _client.from('profiles').select('nombre, apellido').eq('id', viaje['chofer_id']).maybeSingle();
          viaje['chofer'] = chofer;
        } catch (_) {}
      }

      // 3. Cargar Paradas y sus Items (Productos)
      try {
        final paradas = await _client.from('paradas').select('*, parada_items(*)').eq('viaje_id', viajeId).order('orden_secuencia');
        viaje['paradas'] = paradas;
      } catch (_) { viaje['paradas'] = []; }

      // 4. Cargar Gastos
      try {
        final gastos = await _client.from('gastos').select().eq('viaje_id', viajeId).order('fecha');
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

      final viajesData = await _client.from('viajes').select('*, profiles(nombre, apellido)').eq('estado', 'En Curso').timeout(const Duration(seconds: 10));
      final pesajesData = await _client.from('pesajes').select('id').timeout(const Duration(seconds: 10));

      return {
        'totalKg': totalKg,
        'viajesEnCurso': viajesData.length,
        'viajesActivos': List<Map<String, dynamic>>.from(viajesData),
        'tamboresStock': pesajesData.length,
      };
    } catch (e) {
      return {'totalKg': 0.0, 'viajesEnCurso': 0, 'viajesActivos': [], 'tamboresStock': 0};
    }
  }

  /// Logística: Solicitudes (antes Necesidades), Vehículos y Choferes.
  Future<List<Map<String, dynamic>>> getNecesidadesPendientes() async => _fetchList('solicitudes', select: '*, apicultores(nombre, localidad)', filter: {'estado': 'Pendiente'});
  Future<List<Map<String, dynamic>>> getAllNecesidades() async => _fetchList('solicitudes', select: '*, apicultores(nombre, localidad)', order: 'created_at');
  Future<List<Map<String, dynamic>>> getVehiculos() async => _fetchList('vehiculos', order: 'vehiculo_codigo');
  Future<List<Map<String, dynamic>>> getChoferes() async => _fetchList('profiles', filter: {'puesto': 'Chofer'});
  Future<List<Map<String, dynamic>>> getApicultores() async => _fetchList('apicultores', select: '*', order: 'nombre');
  Future<List<Map<String, dynamic>>> getProductos() async => _fetchList('productos', order: 'nombre');
  Future<List<Map<String, dynamic>>> getGastos() async => _fetchList('gastos', select: '*, profiles:chofer_id(nombre, apellido), viajes(viaje_codigo)', order: 'fecha');
  Future<List<Map<String, dynamic>>> getRemitos() async => _fetchList('remitos', select: '*, apicultores(nombre), solicitudes(solicitud_codigo)', order: 'created_at');

  Future<List<Map<String, dynamic>>> _fetchList(String table, {String select = '*', Map<String, String>? filter, String? order}) async {
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
      final viajeResp = await _client.from('viajes').insert(viajeData).select().single();
      final viajeId = viajeResp['id'];
      int seq = 1;
      for (final nec in necesidades) {
        final paradaData = {
          'viaje_id': viajeId,
          'ubicacion': nec['apicultores']?['nombre'] ?? 'Sin Nombre',
          'tipo_operacion': nec['tipo'] ?? 'Operación', 
          'estado': 'Pendiente',
          'orden_secuencia': seq++,
          'localidad': nec['apicultores']?['localidad'] ?? 'S/D',
        };
        
        // Agregar apicultor_id solo si existe en el mapa de necesidad
        if (nec['apicultor_id'] != null) {
          paradaData['apicultor_id'] = nec['apicultor_id'];
        }

        final paradaResp = await _client.from('paradas').insert(paradaData).select().single();

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

  Future<void> createNecesidad(Map<String, dynamic> data) async {
    try { await _client.from('solicitudes').insert(data); } catch (e) { rethrow; }
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
          'ubicacion': nec['apicultores']?['nombre'] ?? 'Sin Nombre',
          'tipo_operacion': nec['tipo'] ?? 'Operación', 
          'estado': 'Pendiente',
          'orden_secuencia': seq++,
          'localidad': nec['apicultores']?['localidad'] ?? 'S/D',
        };
        
        if (nec['apicultor_id'] != null) {
          paradaData['apicultor_id'] = nec['apicultor_id'];
        }

        final paradaResp = await _client.from('paradas').insert(paradaData).select().single();
        
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
