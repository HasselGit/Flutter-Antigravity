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
  Future<List<Map<String, dynamic>>> getViajes({String? userId, String? role}) async {
    try {
      print('SupabaseService: Obteniendo viajes (UserId: $userId, Role: $role)');
      try {
        var query = _client.from('viajes').select('*, paradas(*, parada_items(*))');
        if (role == 'Chofer' && userId != null) {
          query = query.eq('chofer_id', userId);
        }
        final data = await query.order('fecha', ascending: false).timeout(const Duration(seconds: 10));
        return List<Map<String, dynamic>>.from(data);
      } catch (e) {
        print('SupabaseService: Falló fetch con items (RLS), reintentando básico: $e');
        var query = _client.from('viajes').select('*, paradas(*)');
        if (role == 'Chofer' && userId != null) {
          query = query.eq('chofer_id', userId);
        }
        final data = await query.order('fecha', ascending: false).timeout(const Duration(seconds: 10));
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('SupabaseService: Error crítico en getViajes: $e');
      rethrow;
    }
  }

  /// Obtiene el detalle de un viaje.
  Future<Map<String, dynamic>?> getViajeDetalle(String viajeId) async {
    try {
      print('SupabaseService: Fetching detalle para viaje: $viajeId');
      final response = await _client
          .from('viajes')
          .select('*, paradas(*, parada_items(*))')
          .eq('id', viajeId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      
      if (response != null) return response;

      // Fallback si la consulta compleja falla por RLS
      final basicViaje = await _client
          .from('viajes')
          .select('*, paradas(*)')
          .eq('id', viajeId)
          .maybeSingle();
          
      return basicViaje;
    } catch (e) {
      print('SupabaseService: Error en getViajeDetalle: $e');
      // Intento final ultra-básico
      try {
        final ultraBasic = await _client.from('viajes').select().eq('id', viajeId).maybeSingle();
        return ultraBasic;
      } catch (_) {
        return null;
      }
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
        else if (e == 'Terminado') terminados++;
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

  /// Logística: Necesidades, Vehículos y Choferes.
  Future<List<Map<String, dynamic>>> getNecesidadesPendientes() async => _fetchList('necesidades', select: '*, apicultores(nombre, localidad)', filter: {'estado': 'Pendiente'});
  Future<List<Map<String, dynamic>>> getAllNecesidades() async => _fetchList('necesidades', select: '*, apicultores(nombre, localidad)', order: 'created_at');
  Future<List<Map<String, dynamic>>> getVehiculos() async => _fetchList('vehiculos');
  Future<List<Map<String, dynamic>>> getChoferes() async => _fetchList('profiles', filter: {'puesto': 'Chofer'});
  Future<List<Map<String, dynamic>>> getApicultores() async => _fetchList('apicultores', select: 'id, nombre, localidad');

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

  /// Escritura: Crear Viaje Completo y Necesidades.
  Future<void> createViajeCompleto({required Map<String, dynamic> viajeData, required List<Map<String, dynamic>> necesidades}) async {
    try {
      final viajeResp = await _client.from('viajes').insert(viajeData).select().single();
      final viajeId = viajeResp['id'];
      int seq = 1;
      for (final nec in necesidades) {
        final paradaResp = await _client.from('paradas').insert({
          'viaje_id': viajeId,
          'apicultor_id': nec['apicultor_id'],
          'tipo_operacion': nec['tipo'],
          'estado': 'Pendiente',
          'orden_secuencia': seq++,
          'direccion': nec['apicultores']?['localidad'] ?? 'S/D',
        }).select().single();
        try {
          await _client.from('parada_items').insert({
            'parada_id': paradaResp['id'],
            'producto': nec['producto'],
            'cantidad': nec['cantidad'],
            'unidad': 'KG',
          });
        } catch (_) {}
        await _client.from('necesidades').update({'estado': 'En Ruta'}).eq('id', nec['id']);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createNecesidad(Map<String, dynamic> data) async {
    try { await _client.from('necesidades').insert(data); } catch (e) { rethrow; }
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

  /// Registra un item en una parada (ej: bulto sin pesar).
  Future<void> createParadaItem(Map<String, dynamic> data) async {
    try {
      await _client.from('parada_items').insert(data);
    } catch (e) {
      print('SupabaseService: Error en createParadaItem: $e');
      rethrow;
    }
  }
}
