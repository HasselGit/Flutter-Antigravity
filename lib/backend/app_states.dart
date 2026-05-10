/// Constantes de estado centralizadas para toda la aplicación GeoLogística.
/// Todos los estados deben usarse desde aquí para evitar strings duplicados.
class AppStates {
  AppStates._();

  // ── Estados comunes ────────────────────────────────────────────────────────
  static const String pendiente  = 'Pendiente';
  static const String enCurso    = 'En Curso';
  static const String terminado  = 'Terminado';

  // ── Estados de Solicitudes ─────────────────────────────────────────────────
  // Pendiente  → recién creada, disponible para planificar
  // En Curso   → incluida en un viaje planificado
  // Terminado  → parada completada con remito generado

  // ── Estados de Viajes ─────────────────────────────────────────────────────
  // Pendiente  → viaje planificado, esperando carga o salida
  // En Curso   → chofer inició el viaje
  // Terminado  → todas las paradas completadas

  // ── Estados de Paradas ────────────────────────────────────────────────────
  // Pendiente  → parada no visitada
  // En Curso   → chofer en camino o en la parada
  // Terminado  → remito generado

  // ── Estados de Cargas ─────────────────────────────────────────────────────
  // Pendiente  → asignada al viaje, pendiente de carga física
  // En Curso   → Encargado de Depósito iniciando la carga
  // Terminado  → carga completada, depósito circulante actualizado

  /// Normaliza strings de estados anteriores al nuevo estándar.
  static String normalize(String? raw) {
    if (raw == null) return pendiente;
    switch (raw.trim()) {
      case 'Planificado':
      case 'Planificada':
      case 'Cargado':
        return pendiente;
      case 'En Proceso':
      case 'En Curso':
        return enCurso;
      case 'Finalizado':
      case 'Completado':
      case 'Completada':
      case 'Terminado':
        return terminado;
      default:
        return raw;
    }
  }

  /// Color de fondo del badge según estado.
  static int stateBgColor(String estado) {
    switch (estado) {
      case enCurso:    return 0xFFFDEFCC;
      case terminado:  return 0xFFD4F0E1;
      default:         return 0xFFD6E4FF; // Pendiente → azul suave
    }
  }

  /// Color de texto del badge según estado.
  static int stateTextColor(String estado) {
    switch (estado) {
      case enCurso:    return 0xFF7D5700;
      case terminado:  return 0xFF1A6B43;
      default:         return 0xFF1565C0; // Pendiente → azul oscuro
    }
  }

  /// Color del borde izquierdo de tarjeta según estado.
  static int stateBorderColor(String estado) {
    switch (estado) {
      case enCurso:    return 0xFFFDBE49;
      case terminado:  return 0xFF249689;
      default:         return 0xFF1565C0;
    }
  }
}
