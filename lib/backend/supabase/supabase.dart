import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseManager {
  static final client = Supabase.instance.client;
}

abstract class SupabaseTable<R> {
  String get tableName;
  R mapRow(Map<String, dynamic> data);

  Future<List<R>> queryRows({
    required Function(PostgrestFilterBuilder) queryFn,
  }) async {
    final query = SupabaseManager.client.from(tableName).select();
    final response = await queryFn(query);
    return (response as List).map((e) => mapRow(e)).toList();
  }

  Future<List<R>> querySingleRow({
    required Function(PostgrestFilterBuilder) queryFn,
  }) async {
    return queryRows(queryFn: queryFn);
  }
}

extension SupabaseFilterExtensions on PostgrestFilterBuilder {
  PostgrestFilterBuilder eqOrNull(String column, dynamic value) {
    if (value == null) return this;
    return eq(column, value);
  }
}

// VIAJES TABLE
class ViajesTable extends SupabaseTable<ViajesRow> {
  @override
  String get tableName => 'viajes';
  @override
  ViajesRow mapRow(Map<String, dynamic> data) => ViajesRow(data);
}

class ViajesRow {
  ViajesRow(this.data);
  final Map<String, dynamic> data;
  String? get id => data['id'];
  String? get viajeCodigo => data['viaje_codigo'];
  DateTime? get fechaInicio => DateTime.tryParse(data['fecha_inicio'] ?? '');
}

// PARADA ITEMS TABLE
class ParadaItemsTable extends SupabaseTable<ParadaItemsRow> {
  @override
  String get tableName => 'parada_items';
  @override
  ParadaItemsRow mapRow(Map<String, dynamic> data) => ParadaItemsRow(data);
}

class ParadaItemsRow {
  ParadaItemsRow(this.data);
  final Map<String, dynamic> data;
  String? get id => data['id'];
  double? get cantidad => data['cantidad']?.toDouble();
  String? get productoId => data['producto_id'];
}

// V_PARADAS_CON_APICULTOR_FF (View)
class VParadasConApicultorFfTable extends SupabaseTable<VParadasConApicultorFfRow> {
  @override
  String get tableName => 'v_paradas_con_apicultor_ff';
  @override
  VParadasConApicultorFfRow mapRow(Map<String, dynamic> data) => VParadasConApicultorFfRow(data);
}

class VParadasConApicultorFfRow {
  VParadasConApicultorFfRow(this.data);
  final Map<String, dynamic> data;
  String? get id => data['id'];
  String? get viajeId => data['viaje_id'];
  int? get ordenSecuencia => data['orden_secuencia'];
  String? get tipo => data['tipo'];
  String? get localidad => data['localidad'];
  String? get apicultorNombre => data['apicultor_nombre'];
}
