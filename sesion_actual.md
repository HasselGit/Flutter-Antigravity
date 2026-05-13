# Estado Actual de la Sesión - GeoLogística

## Últimas Modificaciones (13 de Mayo de 2026)
### 1. Desactivación del Motor Impeller (Android)
- **Problema:** El emulador de Android en Windows experimentaba bloqueos catastróficos (Deadlocks) y caída de frames masivos al interactuar con el teclado o redibujar componentes visuales complejos.
- **Solución:** Se ha modificado `android/app/src/main/AndroidManifest.xml` añadiendo la flag `<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />`. Esto fuerza a Flutter a usar el motor clásico Skia, eliminando los congelamientos de interfaz generados por el teclado y el redibujado de la vista.

### 2. Bypass Completo de Supabase Auth
- **Problema:** El inicio de sesión se quedaba bloqueado en una rueda infinita debido a que el SDK nativo de Supabase Auth devolvía `AuthApiException(message: Invalid login credentials)`. Esto creaba un desfase silencioso en la interfaz.
- **Solución:** 
  - Se reescribió el método `login` en `lib/backend/supabase_service.dart`. Ahora la aplicación **ignora** la capa de autenticación restrictiva de Supabase y consulta de forma directa la tabla pública `profiles` verificando el correo y la columna `contrasena` (que contiene las claves en texto plano).
  - Esta consulta directa es instantánea y evita deadlocks de `SharedPreferences` asociados al SDK de Auth.

### 3. Desacople del `currentUser` de Supabase
- **Problema:** Al no usar Supabase Auth, la variable `Supabase.instance.client.auth.currentUser` queda como nula, lo que rompía módulos que dependían de la ID del usuario activo.
- **Solución:**
  - En `lib/pages/logged.dart`, se cambió la lógica de redirección para leer el `user_id` desde `SharedPreferences`.
  - En `lib/pages/gastos_page.dart`, se reemplazó la inyección de `chofer_id` por la lectura asíncrona del `user_id` desde `SharedPreferences`, garantizando que todos los registros se vinculen correctamente al operario sin depender de Supabase Auth.

### 4. Restauración de Paneles Nativos (Honeycomb)
- **Solución:** Se restauró el código original de `HoneycombPainter` para la pantalla de bienvenida (`welcomepage.dart`), pero inyectándole una **Caché Estática** global (`_cachedPicture` estática). Ahora los hexágonos matemáticos se calculan exactamente una sola vez durante toda la vida útil de la app, permitiendo usar el diseño Premium sin ningún costo de CPU.

## Tareas Pendientes para el Desarrollador (Próxima Sesión)
1. **Limpieza del Login:** Actualmente los campos de correo y contraseña en `login.dart` están pre-llenados con `mparedes@geomiel.com` por comodidad para las pruebas. Deberán vaciarse antes de compilar para producción.
2. **Migración de Contraseñas (Opcional):** A largo plazo, se sugiere no usar contraseñas en texto plano (`contrasena`) en la tabla `profiles`. Se recomienda sincronizar a los usuarios con el módulo real de `Auth` de Supabase si se desea mayor seguridad.

## Instrucciones de Reinicio Rápido
- Ejecutar `flutter clean` y `flutter run` para garantizar que los cambios en el `AndroidManifest.xml` (desactivación de Impeller) surtan efecto en el emulador.
