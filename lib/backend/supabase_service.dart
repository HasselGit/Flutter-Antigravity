import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'apicultores_data.dart';
import 'app_states.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ─── AUTH ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final cleanEmail = email.trim();
    final cleanPass = password.trim();
    try {
      final authRes = await _client.auth.signInWithPassword(
        email: cleanEmail, password: cleanPass,
      ).timeout(const Duration(seconds: 5));
      if (authRes.user != null) {
        final profile = await _client.from('profiles')
            .select('id, nombre, apellido, email, puesto')
            .eq('id', authRes.user!.id).maybeSingle();
        if (profile != null) return await _saveLocal(profile);
      }
    } catch (e) { print('SupabaseService: Auth falló: $e'); }
    try {
      final response = await _client.from('profiles')
          .select('id, nombre, apellido, email, puesto')
          .eq('email', cleanEmail).timeout(const Duration(seconds: 5));
      if ((response as List).isNotEmpty) {
        final user = (response as List).first;
        return await _saveLocal(user);
      }
    } catch (e) { print('SupabaseService: Login manual falló: $e'); }
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

  // ─── VIAJES ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getViajes({String? userId, String? role}) async {
    try {
      dynamic query = _client.from('viajes')
          .select('id, viaje_codigo, vehiculo_codigo, chofer_id, estado, fecha, descripcion');
      if (role == 'Chofer' && userId != null) {
        query = query.eq('chofer_id', userId);
      }
      final List<dynamic> data = await query
          .order('fecha', ascending: false)
          .timeout(const Duration(seconds: 10));
      final viajes = List<Map<String, dynamic>>.from(data);
      for (var v in viajes) {
        v['estado'] = AppStates.normalize(v['estado']);
        if (v['chofer_id'] != null) {
          try {
            final chofer = await _client.from('profiles')
                .select('nombre, apellido').eq('id', v['chofer_id']).maybeSingle();
            v['chofer'] = chofer;
          } catch (_) { v['chofer'] = null; }
        }
        try {
          final paradas = await _client.from('paradas')
              .select('id, orden_secuencia, tipo, ubicacion, localidad, estado, parada_items(id, producto_codigo, cantidad, unidad)')
              .eq('viaje_id', v['id']).order('orden_secuencia');
          v['paradas'] = paradas;
        } catch (_) { v['paradas'] = []; }
        if (v['vehiculo_codigo'] != null) {
          try {
            final veh = await _client.from('vehiculos')
                .select('vehiculo_codigo, capacidad_kg, capacidad_tambores')
                .eq('vehiculo_codigo', v['vehiculo_codigo']).maybeSingle();
            v['capacidad_kg'] = veh?['capacidad_kg'];
          } catch (_) {}
        }
      }
      return viajes;
    } catch (e) {
      print('SupabaseService: Error en getViajes: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getViajeDetalle(dynamic viajeId) async {
    try {
      final viaje = await _client.from('viajes')
          .select('id, viaje_codigo, vehiculo_codigo, chofer_id, estado, fecha, descripcion')
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
        final paradas = await _client.from('paradas')
            .select('id, viaje_id, orden_secuencia, tipo, ubicacion, localidad, estado, remito_id, parada_items(id, producto_codigo, cantidad, unidad)')
            .eq('viaje_id', viajeId).order('orden_secuencia');
        viaje['paradas'] = paradas;
      } catch (_) { viaje['paradas'] = []; }
      try {
        final gastos = await _client.from('gastos')
            .select('id, categoria, monto, fecha, comprobante_url')
            .eq('viaje_id', viajeId).order('fecha');
        viaje['gastos'] = gastos;
      } catch (_) { viaje['gastos'] = []; }
      return viaje;
    } catch (e) {
      print('SupabaseService: Error en getViajeDetalle: $e');
      return null;
    }
  }

  Future<void> updateViajeEstado(String viajeId, String nuevoEstado) async {
    await _client.from('viajes').update({'estado': nuevoEstado}).eq('id', viajeId);
  }

  // ─── STATS ────────────────────────────────────────────────────────────────

  Future<Map<String, int>> getStats({String? userId, String? role}) async {
    try {
      dynamic query = _client.from('viajes').select('estado');
      if (role == 'Chofer' && userId != null) query = query.eq('chofer_id', userId);
      final data = await query.timeout(const Duration(seconds: 10));
      int pendientes = 0, enCurso = 0, terminados = 0;
      for (final v in data) {
        final e = AppStates.normalize(v['estado']);
        if (e == AppStates.pendiente) pendientes++;
        else if (e == AppStates.enCurso) enCurso++;
        else if (e == AppStates.terminado) terminados++;
      }
      return {'planificados': pendientes, 'en_curso': enCurso, 'terminados': terminados};
    } catch (e) {
      return {'planificados': 0, 'en_curso': 0, 'terminados': 0};
    }
  }

  Future<Map<String, dynamic>> getGerenteStats() async {
    try {
      final paradasData = await _client.from('paradas')
          .select('bruto_kg').not('bruto_kg', 'is', null).timeout(const Duration(seconds: 10));
      double totalKg = (paradasData as List).fold(0.0, (sum, p) => sum + ((p['bruto_kg'] as num?)?.toDouble() ?? 0));
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
    final solicitudes = await _fetchList('solicitudes',
        select: 'id, apicultor_id, producto, cantidad, tipo, estado, created_at',
        filter: {'estado': AppStates.pendiente});
    return await _joinApicultores(solicitudes);
  }

  Future<List<Map<String, dynamic>>> getAllNecesidades() async {
    final solicitudes = await _fetchList('solicitudes',
        select: 'id, apicultor_id, solicitud_codigo, producto, cantidad, tipo, localidad, estado, created_at',
        order: 'created_at');
    return await _joinApicultores(solicitudes);
  }

  Future<List<Map<String, dynamic>>> _joinApicultores(List<Map<String, dynamic>> solicitudes) async {
    if (solicitudes.isEmpty) return [];
    try {
      final apicultores = await getApicultores();
      final Map<String, Map<String, dynamic>> apiMap = {};
      for (var a in apicultores) {
        final id = a['id']?.toString().trim();
        if (id != null) apiMap[id] = a;
      }
      for (var s in solicitudes) {
        final apiId = s['apicultor_id']?.toString().trim();
        if (apiId != null && apiMap.containsKey(apiId)) {
          s['apicultores'] = apiMap[apiId];
        } else {
          s['apicultores'] = {'nombre': 'S/D', 'localidad': s['localidad'] ?? 'S/D'};
          if (apiId != null && apiId.length > 5) {
            try {
              final api = await _client.from('apicultores')
                  .select('id, nombre, localidad').eq('id', apiId).maybeSingle();
              if (api != null) s['apicultores'] = api;
            } catch (_) {}
          }
        }
      }
    } catch (e) { print('SupabaseService: Error uniendo apicultores: $e'); }
    return solicitudes;
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

  Future<List<Map<String, dynamic>>> getVehiculos() async =>
      _fetchList('vehiculos',
          select: 'id, vehiculo_codigo, patente, modelo, capacidad_kg, capacidad_tambores, carga_actual_kg, carga_actual_tambores',
          order: 'vehiculo_codigo');

  Future<List<Map<String, dynamic>>> getChoferes() async =>
      _fetchList('profiles',
          select: 'id, nombre, apellido, puesto',
          filter: {'puesto': 'Chofer'});

  Future<List<Map<String, dynamic>>> getApicultores() async {
    try {
      final list = await _fetchList('apicultores',
          select: 'id, nombre, localidad, apicultor_codigo, provincia, dni, cuit, renapa, telefono',
          order: 'nombre');
      if (list.isNotEmpty) return list;
      return ApicultoresData.fallbackApicultores;
    } catch (e) {
      return ApicultoresData.fallbackApicultores;
    }
  }

  Future<List<Map<String, dynamic>>> getProductos() async =>
      _fetchList('productos',
          select: 'id, descripcion, codigo, unidad',
          order: 'descripcion');

  Future<List<Map<String, dynamic>>> getGastos() async {
    final gastos = await _fetchList('gastos',
        select: 'id, categoria, monto, fecha, chofer_id, viaje_id, comprobante_url',
        order: 'fecha');
    for (var g in gastos) {
      if (g['chofer_id'] != null) {
        try {
          final profile = await _client.from('profiles')
              .select('nombre, apellido').eq('id', g['chofer_id']).maybeSingle();
          g['profiles'] = profile;
        } catch (_) {}
      }
    }
    return gastos;
  }

  Future<List<Map<String, dynamic>>> getRemitos() async {
    try {
      final data = await _client.from('remitos')
          .select('*, apicultores(nombre), paradas(tipo, neto_kg)')
          .order('created_at', ascending: false);
      final remitos = List<Map<String, dynamic>>.from(data as List);
      for (var r in remitos) {
        if (r['paradas'] != null) {
          r['tipo'] = r['paradas']['tipo'];
          r['peso_neto'] = r['paradas']['neto_kg'];
        }
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
    final viajeResp = await _client.from('viajes').insert(data).select('id').single();
    final viajeId = viajeResp['id'];
    int seq = 1;
    for (final nec in necesidades) {
      final paradaResp = await _client.from('paradas').insert({
        'viaje_id': viajeId,
        'ubicacion': nec['apicultores']?['nombre'] ?? nec['apicultor'] ?? 'Sin Nombre',
        'tipo': nec['tipo'] ?? 'Operación',
        'estado': AppStates.pendiente,
        'orden_secuencia': seq++,
        'localidad': nec['apicultores']?['localidad'] ?? nec['localidad'] ?? 'S/D',
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
      await _client.from('solicitudes')
          .update({'estado': AppStates.enCurso}).eq('id', nec['id']);
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
      await _client.from('solicitudes')
          .update({'estado': AppStates.enCurso}).eq('id', nec['id']);
    }
  }

  Future<void> createNecesidad(Map<String, dynamic> data) async =>
      await _client.from('solicitudes').insert(data);

  Future<void> createPesaje(Map<String, dynamic> data) async =>
      await _client.from('pesajes').insert(data);

  Future<void> createGasto(Map<String, dynamic> data) async =>
      await _client.from('gastos').insert(data);

  Future<void> createProducto(Map<String, dynamic> data) async =>
      await _client.from('productos').insert(data);

  Future<void> createParadaItem(Map<String, dynamic> data) async =>
      await _client.from('parada_items').insert(data);

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
}
