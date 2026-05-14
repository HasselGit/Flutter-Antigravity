# Análisis General de Estado - GeoLogística

**Fecha de Análisis:** 14 de Mayo de 2026

## 1. Resumen Arquitectónico
GeoLogística es una aplicación móvil desarrollada en Flutter orientada a la gestión logística apícola. La estructura de la aplicación está dividida en diferentes módulos según los perfiles de usuario (Chofer, Gerente, Depósito, Compras, etc.).

*   **Backend:** Supabase. Se manejan tablas como `profiles`, `viajes`, `rutas`, `paradas`, `solicitudes`, `cargas`, `vehiculos`, `pesajes` y `gastos`.
*   **Autenticación:** Bypass activo. Se omite el SDK nativo de Supabase Auth en favor de consultas directas a la tabla `profiles` por correo y contraseña en texto plano, guardando la sesión en `SharedPreferences`.
*   **Enrutamiento:** `GoRouter`.
*   **Estado Global:** Mayormente delegado a la navegación y llamadas asíncronas directas al servicio `SupabaseService`.
*   **Estilos y UI:** Basados en una capa custom de "Stitch Premium" (`DesignTokens`, fondos dinámicos Cacheados como `HoneycombPainter`).

## 2. Estado Actual (Últimas Modificaciones)
Según los registros de la sesión y la revisión del código fuente, el estado actual refleja un alto enfoque en el **rendimiento y la estabilización de procesos core**:

1.  **Rendimiento del Emulador (Android):** Se desactivó el motor gráfico Impeller (`EnableImpeller` = `false` en `AndroidManifest.xml`) para mitigar deadlocks severos al escribir en teclados y transicionar vistas.
2.  **Sistema de Login Totalmente Desacoplado:** El método `login()` en `SupabaseService.dart` hace un `.select()` directo validando email y `contrasena`. Evita el caché tóxico de Supabase Auth.
3.  **Gestión de Sesión:** El ID del usuario y rol se manejan ahora nativamente mediante `SharedPreferences` (ej. `prefs.getString('user_id')`). Las pantallas que usaban `Supabase.instance.client.auth.currentUser` han sido factorizadas.
4.  **Optimización Visual:** El fondo matemático de panales en `WelcomePage` utiliza una caché estática de dibujado (`_cachedPicture`) para abatir el uso del CPU a 0% en reposo.

## 3. Estado de los Módulos Core
*   **Módulo de Viajes y Rutas:** El flujo de creación de Viajes asocia las Solicitudes a Paradas (`createViajeCompleto`). Si la ruta no se crea correctamente, hay un `fallback` implementado.
*   **Gestión de Solicitudes/Necesidades:** Funcional. Los apicultores pueden solicitar operaciones (Recolección/Distribución), las cuales se agrupan en viajes.
*   **Módulo de Cargas (Depósito):** Lógica sólida. Al completar una carga (`updateCargaEstado`), el sistema interactúa directamente con los vehículos (`_actualizarDepositoCirculante`) actualizando los kilogramos y la cantidad de tambores en circulación basado en constantes de negocio (Ej: Tambor lleno = 300kg, Tambor vacío = 20kg).
*   **Depuración de Entorno:** El entorno IDE de VS Code y el compilador han sido recién saneados: SDK de Java mapeado, variables de entorno Flutter incluidas y el emulador está respondiendo a compilaciones de depuración (`assembleDebug`).

## 4. Problemas Conocidos y Tareas Pendientes (Next Steps)

### A. Tareas Operativas Inmediatas
*   **Limpieza de Login Hardcodeado:** En `login.dart` probablemente existan credenciales pre-llenadas (`mparedes@geomiel.com`) facilitadas para testing. Deben eliminarse o condicionarse solo a modo Debug (`kDebugMode`) antes de llevar a producción.
*   **Migración a Sistema Hash de Contraseñas:** El almacenamiento de claves en texto plano (`contrasena`) en la tabla pública `profiles` supone un riesgo severo de seguridad en producción. A futuro, este método "Bypass" debe ser reemplazado por la API robusta de Auth, o bien implementar un algoritmo de Hash local si se va a seguir usando una tabla personalizada.

### B. Posibles Puntos Críticos (Vulnerabilidades del Código)
1.  **`getViajeDetalle`:** Hay múltiples llamadas try-catch anidadas que suprimen errores de relaciones en la BD (`rutas`, `gastos`, `choferes`). Si la estructura de Supabase cambia, la UI simplemente mostrará datos en blanco sin registrar la falla. Se recomienda implementar un logger centralizado.
2.  **`deleteViaje`:** Borra en cascada liberando solicitudes, borrando paradas y rutas. Si el viaje ya tenía `cargas` o `pesajes` asociados accidentalmente (o por un flujo no previsto), podría lanzar excepciones SQL de integridad referencial. Debería agregarse validación de "Viaje iniciado/procesado" antes de permitir su borrado.
3.  **Dependencia Total de Conectividad:** La aplicación hace consultas pesadas sincrónicas a la base de datos (Ej: `getGerenteStats`). Sin conexión a internet, los flujos se rompen inmediatamente porque no hay un sistema robusto de caché offline (`Hive` o `SQLite`) más allá de `SharedPreferences` para la sesión.

## 5. Conclusión
El entorno de desarrollo está en **condiciones óptimas (Verde)**. Los conflictos ambientales y de emulación están totalmente mitigados. El sistema base es funcional y la lógica relacional entre Vehículos -> Viajes -> Rutas -> Paradas -> Solicitudes está debidamente orquestada en `SupabaseService`.

**Recomendación Inmediata para avanzar:** 
Podemos proceder a desarrollar nuevas features o abocarnos en pulir la lógica de la Interfaz de Usuario. Indícame qué módulo o archivo específico deseas que ataquemos a continuación.
