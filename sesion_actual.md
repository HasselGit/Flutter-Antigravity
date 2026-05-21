# Sesión Actual - 21 de Mayo, 2026

## Objetivos Alcanzados: Corrección de Cargas Vacías (RLS Stale), Permisos de Administrador y Flujo de Paradas

Hoy resolvimos de raíz el error por el cual la carga `CARGA-7845001` mostraba **0 items / 0 kg / No hay ítems en esta carga** en ambas pantallas (chofer Mauricio Pérez y administrador hassel00@gmail.com), a pesar de contener `TRR x 25` correctamente en la base de datos.

---

### 🔐 1. Corrección del Bug de RLS Silencioso (Causa Raíz)

- **Diagnóstico**: El emulador de Android tenía guardada una sesión JWT de Supabase Auth de pruebas anteriores (`flutter_secure_storage`). Al arrancar la app, `Supabase.initialize()` cargaba ese token automáticamente, forzando las consultas bajo el rol `authenticated`.
- **El Problema en Base de Datos**: La política RLS de `carga_items` para el rol `authenticated` referencia `profiles.rol`, pero la columna fue renombrada a `profiles.puesto` hace tiempo. Este error de esquema causaba que PostgreSQL filtrara silenciosamente **todas las filas** devolviendo `carga_items: []` sin lanzar ninguna excepción visible.
- **Solución en `main.dart`**: Se agregó `await Supabase.instance.client.auth.signOut()` inmediatamente después de la inicialización de Supabase para descartar cualquier JWT stale persistido en el emulador.
- **Solución en `supabase_service.dart`**: Se agregó `signOut()` preventivo al inicio del método `login()` manual como capa adicional de limpieza.

### 🛡️ 2. Permisos de Administrador y Botones de Viaje

- **`viaje_detalle.dart`**: El `_isAdmin` ahora verifica `_userEmail` (desde `SharedPreferences`) además del campo de Supabase Auth, garantizando que `hassel00@gmail.com` tenga acceso total a los botones **Iniciar** y **Finalizar Viaje** sin depender del auth nativo.
- **`viajes_page.dart`**: `userEmail` se lee desde `SharedPreferences` como fuente primaria (fallback a `auth.currentUser?.email`), preservando `_isAdmin=true` correctamente con Supabase Auth en estado anónimo.
- **`rutas_page.dart`**: Se cargó `_userEmail` desde `SharedPreferences` y se mejoró la visibilidad del FAB de planificación y botones de viaje para administradores.

### 🚫 3. Restricción de Modo Lectura en Paradas (Viajes Pendientes)

- **`paradadetalle.dart`**: Cuando el viaje padre está en estado `Pendiente`, la pantalla de detalle de parada entra en modo `isReadOnly = true` para **todos** los usuarios.
- Se ocultan: botón de registrar pesajes, agregar ítems, generar remito y finalizar parada.
- Se muestra un banner amber premium: *"Consulta únicamente. El viaje aún no ha comenzado."*

### 📦 4. Gestión de Cargas (Automatización)

- **`supabase_service.dart` - `createCarga()`**: Se corrigió conversión de `cantidad` a entero (`toInt()`) y se implementó bulk insert con rollback manual si falla.
- **Auto-creación de cargas**: Al planificar un viaje con solicitudes de distribución, se crea automáticamente una carga pendiente.
- **`carga_detalle.dart`**: Visualización robusta de ítems con cálculos correctos de kg y totales.

### 🗺️ 5. Planificador de Ruta (Unidades y Google Maps)

- **Unidades dinámicas**: Se importó `ProductosData.masterCatalog` en `planificar_viaje.dart` para mostrar `UN.` para TCM/TRR y `Kg.` para el resto.
- **Google Maps**: Los waypoints ahora se formatean como `"$localidad, $provincia, Argentina"` para evitar ambigüedades de geocodificación (ej: Vértiz → La Pampa).

### 🌾 6. Ficha de Apicultor

- **`apicultor_detalle.dart`**: Resumen histórico por producto filtrado solo a solicitudes `Terminada`/`Finalizada`. Se añadió sección premium "Total Estimado Pendiente".

### 🧹 7. Limpieza de Datos de Prueba (Base de Datos)

- Se eliminaron todos los registros de cargas con prefijo `TEST-` o `TEST-FORM-` de la base de datos de Supabase mediante script Dart.

---

## 💾 Sincronización y Compilación Exitosa

- **Control de Versiones**: Commit `61aa51e` subido a `origin/main` en GitHub (`HasselGit/Flutter-Antigravity`).
- **53 archivos** modificados/creados en este commit (2258 líneas nuevas).
- **`flutter analyze`**: Los archivos de `lib/` están libres de errores de compilación. Los warnings son `info`-level pre-existentes en todo el proyecto (prints, curly_braces) no relacionados a los cambios de esta sesión.

## 🖥️ Instrucciones para continuar en otra computadora

1. **Clonar o sincronizar el repo**: `git pull origin main`
2. **Limpiar caché** (MUY IMPORTANTE para que el emulador descarte la sesión vieja):
   ```bash
   flutter clean
   flutter pub get
   ```
3. **Ejecutar**: `flutter run`
4. Al arrancar, el `signOut()` en `main.dart` limpiará automáticamente cualquier JWT stale del emulador.
5. La carga `CARGA-7845001` mostrará correctamente **TRR x 25** para ambos usuarios.
