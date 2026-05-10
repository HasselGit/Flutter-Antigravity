# Blueprint Maestro de Sesión: GeoLogística
**Fecha de actualización:** 09 de Mayo de 2026 (20:30hs)

## 1. Contexto del Proyecto
GeoLogística es una plataforma integral para la gestión logística de la industria apícola, diseñada bajo el sistema estético "Stitch Premium" (Verde Bosque, Dorado Miel, Crema). La aplicación gestiona desde la solicitud del productor hasta la entrega final y el pesaje, integrando Supabase como motor de datos.

## 2. Arquitectura Técnica
*   **Framework:** Flutter (Mobile/Desktop).
*   **Backend:** Supabase (Auth, DB, Storage). URL: `https://suwcqdlxnmfcvmlnzizl.supabase.co`
*   **Navegación:** GoRouter (Rutas centralizadas en `main.dart`). Usa `context.go()` para navegación principal y `context.push()` para sub-pantallas.
*   **Estado:** State Management local + SharedPreferences para persistencia de roles y sesión.
*   **Diseño:** `DesignTokens` (`lib/backend/design_tokens.dart`). Paleta: `#1E302C` (primary), `#C68E17` (secondary), `#FBFBFB` (surface).
*   **Fuentes:** Manrope (títulos), Work Sans (labels), Inter (body).

## 3. Modelo de Datos y Lógica de Negocio (Core)

### Tablas en Supabase (confirmadas y activas):
| Tabla | Propósito |
|---|---|
| `apicultores` | Maestro de productores. `apicultor_codigo` (ej: A01887) es el ID humano. |
| `solicitudes` | Pedidos de Recolección/Distribución. Estados: Pendiente → En Curso → Terminado |
| `viajes` | Contenedor de rutas. Estados: **Pendiente → En Curso → Terminado** (estandarizados) |
| `paradas` | Nodos de un viaje. Tiene `viaje_id`, `tipo` (Recoleccion/Distribucion), `localidad`, `ubicacion`. Estados: Pendiente → Terminado |
| `parada_items` | Productos por parada. Campos: `producto_codigo`, `cantidad` (neto), `total_kg` (bruto). |
| `pesajes` | Un registro por tambor. Campos: `parada_id`, `viaje_id`, `apicultor_id`, `senasa_codigo`, `peso_bruto`, `tara`, `peso_neto`. |
| `cargas` | **NUEVA (09/05/2026)**. Carga asignada a un viaje. Estados: Pendiente → En Curso → Terminado. Gestionada por Encargado de Depósito. |
| `carga_items` | Ítems de cada carga. Campos: `carga_id`, `producto_codigo`, `cantidad`, `unidad`. |
| `remitos` | Documentos digitales vinculados a parada/viaje. |
| `vehiculos` | Vehículos con `capacidad_kg`, `capacidad_tambores`, **`carga_actual_kg`**, **`carga_actual_tambores`** (depósito circulante). |

### Estados Unificados (estándar para TODA la app):
```
TODOS LOS ESTADOS = Pendiente | En Curso | Terminado
```
- ~~`Planificado`~~ → `Pendiente`
- ~~`En Proceso`~~ → `En Curso`
- ~~`Finalizado`~~ / ~~`Completado`~~ → `Terminado`
- Las constantes están centralizadas en `lib/backend/app_states.dart`

### Flujo de Negocio Completo:
```
SOLICITUD (Pendiente)
    ↓ Gerente/CEO/Compras planifica
VIAJE (Pendiente) + PARADAS (Pendientes) + PARADA_ITEMS
    ↓ Gerente/CEO/Compras asigna carga (opcional — no todos los viajes tienen carga)
CARGA (Pendiente) — asignada al viaje, Depósito la gestiona
    ↓ Encargado de Depósito: INICIAR CARGA
CARGA (En Curso) — Depósito cargando el camión
    ↓ Encargado de Depósito: CONFIRMAR CARGA TERMINADA
CARGA (Terminado) → vehiculo.carga_actual_kg actualizado
    ↓ Chofer: INICIAR VIAJE (desde ViajeDetalle)
VIAJE (En Curso) — Chofer en ruta
    ↓ En cada parada: pesaje (opcional en Recolección) → firma → PDF
PARADA (Terminada) + REMITO (Emitido)
    ↓ Chofer: FINALIZAR VIAJE (cuando todas las paradas terminadas)
VIAJE (Terminado) + SOLICITUD (Terminada)
```

### Reglas de Negocio Clave:
| Regla | Implementación |
|---|---|
| No todo viaje tiene carga | Cargas es entidad separada y opcional por viaje |
| No toda recolección requiere pesaje | Sección de pesaje es OPCIONAL (visible pero no obligatoria) |
| Chofer NO puede cambiar ruta | Sin botón de edición en ViajeDetalle para rol Chofer |
| Cambio de ruta = autorización del Gerente | Solo Gerente/CEO/Compras acceden a PlanificarViaje |
| Camión como depósito circulante | `carga_actual_kg` se suma con Carga Terminada |
| Alerta de capacidad | Visible en CargaDetalle y VehiculoDetalle |

## 4. Arquitectura de Archivos Clave
```
lib/
├── main.dart                    ← GoRouter con todas las rutas
├── backend/
│   ├── app_states.dart          ← NUEVO: constantes de estado centralizadas + normalizer
│   ├── design_tokens.dart       ← Paleta, tipografía, estilos de botones
│   └── supabase_service.dart    ← Queries de datos (getCargas, createCarga, updateCargaEstado, etc.)
└── pages/
    ├── gerentehome.dart         ← Dashboard Gerencial (referencia de diseño de AppBar)
    ├── choferhome.dart          ← Dashboard Chofer. Tabs: PENDIENTES / EN CURSO / TERMINADOS
    ├── depositohome.dart        ← Hub del Depósito: acceso a Cargas, Vehículos, Remitos, Viajes
    ├── cargas_page.dart         ← NUEVA: lista de cargas con 3 tabs de estado (mismo estilo rutas_page)
    ├── carga_detalle.dart       ← NUEVA: detalle de carga + barra de depósito circulante + cambio de estado
    ├── viaje_detalle.dart       ← Detalle de viaje. Botones INICIAR/FINALIZAR para Chofer. Ruta bloqueada.
    ├── paradadetalle.dart       ← Operación en parada. Pesaje OPCIONAL. Fix: navega a RemitoPage correctamente.
    ├── agregar_pesaje.dart      ← Formulario por tambor. Guarda en tabla pesajes.
    ├── planificar_viaje.dart    ← Crear/editar viajes (solo Gerente/CEO/Compras)
    ├── pesajes_page.dart        ← Lista de pesajes agrupados por viaje/parada
    ├── remitos_lista_page.dart  ← Lista de remitos PDF con filtros
    └── remito_page.dart         ← Generación de remito digital (firma + PDF + WhatsApp)
```

## 5. Convenciones de UI — Estándar de AppBar
Todas las páginas principales deben seguir el patrón de `gerentehome.dart`:
```dart
AppBar(
  backgroundColor: Colors.white,   // o DesignTokens.surface
  elevation: 0,
  centerTitle: false,               // ← SIEMPRE false
  leading: IconButton(
    icon: Icon(Icons.arrow_back_ios_new_rounded, color: DesignTokens.primary, size: 20),
    onPressed: () => context.go('/home'),  // go() para módulos principales
  ),
  title: Text('Nombre de Página', style: DesignTokens.headlineStyle()),
)
```

## 6. Avances Completados en Sesión 09/05/2026 (tarde/noche)

### Estandarización de Estados:
- ✅ **`app_states.dart`** creado: constantes `Pendiente`, `En Curso`, `Terminado` + método `normalize()` + helpers de colores.
- ✅ **Migración en Supabase**: todos los registros históricos migrados al nuevo estándar.
- ✅ **`choferhome.dart`**: tabs renombrados, comparaciones actualizadas a `AppStates.*`.
- ✅ **`supabase_service.dart`**: `getStats()` y creación de viajes usan nuevos estados.

### Módulo de Cargas (NUEVO):
- ✅ **Tabla `cargas`** y **`carga_items`** creadas en Supabase.
- ✅ **`cargas_page.dart`**: lista con tabs Pendiente/En Curso/Terminado. Mismo formato de card que `rutas_page.dart`. FAB para crear carga (solo Gerente/CEO/Compras).
- ✅ **`carga_detalle.dart`**: header, barra de depósito circulante (carga actual vs capacidad, alerta si excede), lista de ítems, botones de cambio de estado (solo Encargado de Depósito: INICIAR CARGA → CONFIRMAR TERMINADA).
- ✅ **`depositohome.dart`** rediseñado: hub con grid de acciones rápidas + alertas de cargas pendientes.

### Depósito Circulante del Vehículo:
- ✅ Columnas `carga_actual_kg` y `carga_actual_tambores` agregadas a tabla `vehiculos`.
- ✅ `_actualizarDepositoCirculante()` en `supabase_service.dart`: se ejecuta al confirmar carga `Terminada`.
- ✅ Visualización en `carga_detalle.dart`: barra de progreso kg/tambores + texto proyectado.

### Fix Crítico — Remito:
- ✅ **`paradadetalle.dart`**: `_generarRemito()` ahora navega correctamente a `/remito` pasando `paradaId`, `receptorTipo`, `receptorNombre`, `receptorDni` como query params.

### Chofer — Cambio de Estado del Viaje:
- ✅ **`viaje_detalle.dart`**: botón **INICIAR VIAJE** (azul) cuando estado `Pendiente` y tiene paradas.
- ✅ Botón **FINALIZAR VIAJE** (verde) cuando estado `En Curso` y todas las paradas están `Terminado`.
- ✅ Aviso "RUTA BLOQUEADA — Contacte al Gerente" cuando viaje `En Curso`.
- ✅ Botón de editar ruta solo visible para roles Gerente/CEO/Compras.

### Rutas en `main.dart`:
- ✅ `/cargas` → `CargasPageWidget`
- ✅ `/cargaDetalle?id=X` → `CargaDetalleWidget(cargaId: X)`
- ✅ `/cargaDetalle?new=true` → `CargaDetalleWidget(isNew: true)`

## 7. Estado Técnico del Entorno
- **Compilación**: ✅ `flutter build apk --debug` → `Exit code: 0` — BUILD SUCCESS.
- **App corriendo**: ✅ `flutter run -d emulator-5554` — activa en emulador Android.
- **Supabase**: Tablas `cargas`, `carga_items` activas. Columnas `carga_actual_*` en `vehiculos`. Estados migrados.
- **GitHub**: Sincronizar al final de cada sesión.
- **Java**: Java 17. Warnings de `options source 8` son ignorables.
- **Emulador**: `sdk gphone64 x86 64` (API 34 Android). `emulator-5554`.

## 8. Pendientes — Próxima Sesión
1. **Vincular solicitudes al cerrar remito**: al finalizar una parada (generar remito), cambiar `solicitudes.estado = 'Terminado'` para las solicitudes relacionadas.
2. **VehiculoDetalle**: mostrar sección "DEPÓSITO CIRCULANTE" con barra de progreso kg/tambores.
3. **Gastos vinculados al viaje activo**: el chofer registra gastos directamente desde ViajeDetalle.
4. **WhatsApp con número precargado**: el link `wa.me/` debe incluir el teléfono del apicultor.
5. **Proteger edición de viajes activos**: no permitir `updateViajeCompleto` si hay paradas con remito generado.
6. **Testing flujo completo**: Solicitud → Planificación → Carga → Depósito → Viaje → Pesaje → Remito.

---
*GeoLogística v1.2.0 — "Cargas & Estados Unificados" — 09/05/2026 20:30hs*
