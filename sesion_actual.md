# Blueprint Maestro de Sesión: GeoLogística
**Fecha de actualización:** 09 de Mayo de 2026 (22:56hs)

## 1. Contexto del Proyecto
GeoLogística es una plataforma integral para la gestión logística de la industria apícola, diseñada bajo el sistema estético "Stitch Premium" (Verde Bosque, Dorado Miel, Crema). La aplicación gestiona desde la solicitud del productor hasta la entrega final y el pesaje, integrando Supabase como motor de datos.

## 2. Arquitectura Técnica
*   **Framework:** Flutter (Mobile/Desktop).
*   **Backend:** Supabase (Auth, DB, Storage). URL: `https://suwcqdlxnmfcvmlnzizl.supabase.co`
*   **Navegación:** GoRouter (Rutas centralizadas en `main.dart`). Usa `context.go()` para navegación principal y `context.push()` para sub-pantallas.
*   **Estado:** State Management local + SharedPreferences para persistencia de roles y sesión.
*   **Diseño:** `DesignTokens` (`lib/backend/design_tokens.dart`). Paleta: `#1E302C` (primary), `#C68E17` (secondary), `#FBFBFB` (surface).
*   **Fuentes:** Manrope (títulos), Work Sans (labels), Inter (body).

## 3. Usuarios y Roles (Supabase — tabla `profiles`)

| Nombre | Apellido | Rol (puesto) | Email |
|---|---|---|---|
| Cristian | Muse | Chofer | cmuse@geomiel.com |
| Alberto | Gomez | Chofer | agomez@geomiel.com |
| Esteban | Fernandez | Chofer | efernandez@geomiel.com |
| Mauricio | Perez | Chofer | mperez@geomiel.com |
| Carlos | Santana | **Encargado de Deposito** | csantana@geomiel.com |
| Carolina | Merlo | **Encargado de Deposito** | cmerlo@geomiel.com |
| Mariano | Paredes | CEO | mparedes@geomiel.com |
| Hassel | Espinosa | Compras | hespinosa@geomiel.com |
| Leon | Castellanos | Compras | lcastellanos@geomiel.com |
| Roberto | Steierd | Compras | rsteierd@geomiel.com |

> **Nota:** El rol `Deposito` fue migrado a `Encargado de Deposito` en Supabase el 09/05/2026.

## 4. Routing por Rol

| Rol | Home que ve |
|---|---|
| `Chofer` | ChoferHome — tabs Pendientes / En Curso / Terminados |
| `Encargado de Deposito` | Card "Depósito" en HomePageWidget → `/depositoHome` |
| `Gerente` / `CEO` | Card "Gestión de Viajes" + "Dashboard" |
| `Compras` | Card "Planificador" + "Solicitudes" (sin admin) |

## 5. Modelo de Datos y Lógica de Negocio (Core)

### Tablas en Supabase (confirmadas y activas):
| Tabla | Propósito |
|---|---|
| `apicultores` | Maestro de productores. `apicultor_codigo` (ej: A01887) es el ID humano. |
| `solicitudes` | Pedidos. Estados: **Pendiente → En Curso → Terminado**. 22 pendientes listos. |
| `viajes` | Contenedor de rutas. Estados: **Pendiente → En Curso → Terminado** |
| `paradas` | Nodos de un viaje. Tipos: `Recoleccion` / `Distribucion`. |
| `parada_items` | Productos por parada: `producto_codigo`, `cantidad`, `unidad`. |
| `pesajes` | Registro por tambor: `peso_bruto`, `tara`, `peso_neto` (calculado). |
| `cargas` | Carga asignada a viaje. Estados: Pendiente → En Curso → Terminado. |
| `carga_items` | Items de carga: `producto_codigo`, `cantidad`, `unidad`. |
| `remitos` | Documentos digitales vinculados a parada/viaje. |
| `vehiculos` | `capacidad_kg`, `capacidad_tambores`, `carga_actual_kg`=0, `carga_actual_tambores`=0. |
| `profiles` | Usuarios con `puesto` como rol. |

### Estados Unificados (TODA la app):
```
Pendiente | En Curso | Terminado
```
Centralizados en `lib/backend/app_states.dart`

### Flujo Completo de Prueba (limpio desde hoy):
```
1. Gerente/CEO → Planificar Viaje → selecciona solicitudes (22 disponibles)
2. Encargado Depósito → Cargas → Nueva Carga → Iniciar → Confirmar Terminada
3. Chofer → Ver viaje en Pendientes → INICIAR VIAJE
4. Por cada parada → Pesaje (opcional) → Generar Remito Digital
5. Cuando todas terminadas → FINALIZAR VIAJE
```

## 6. Archivos Clave

```
lib/
├── main.dart                    ← GoRouter con todas las rutas
├── backend/
│   ├── app_states.dart          ← Constantes de estado + normalizer + colores
│   ├── design_tokens.dart       ← Paleta, tipografía, estilos de botones
│   └── supabase_service.dart    ← getCargas, getCargaDetalle, createCarga,
│                                   updateCargaEstado, updateViajeEstado, depósito circulante
└── pages/
    ├── homepage.dart            ← Grid de módulos por rol. Card Depósito para Encargado.
    ├── gerentehome.dart         ← Dashboard Gerencial
    ├── choferhome.dart          ← Tabs: PENDIENTES / EN CURSO / TERMINADOS
    ├── depositohome.dart        ← Hub: grid Cargas / Vehículos / Remitos / Viajes
    ├── cargas_page.dart         ← Lista de cargas con 3 tabs
    ├── carga_detalle.dart       ← Detalle + barra depósito circulante + cambio estado
    ├── viaje_detalle.dart       ← INICIAR/FINALIZAR para Chofer + ruta bloqueada
    ├── paradadetalle.dart       ← Pesaje OPCIONAL. Fix: navega a RemitoPage correctamente.
    ├── agregar_pesaje.dart      ← Formulario por tambor → tabla pesajes
    ├── planificar_viaje.dart    ← Crear/editar viajes (solo Gerente/CEO/Compras)
    └── remito_page.dart         ← Generación de remito digital
```

## 7. Estado Técnico
- **Compilación**: ✅ `flutter build apk --debug` → EXIT CODE 0
- **Emulador**: `sdk gphone64 x86 64` (Android API 34). `emulator-5554`.
- **Supabase**: Limpio — 0 viajes, 0 paradas, 0 cargas, 0 remitos, 0 pesajes. 22 solicitudes en Pendiente.
- **Vehículos**: 5 vehículos con `carga_actual_kg = 0` y `carga_actual_tambores = 0`.

## 8. Convención — Comando "guarda todo"

Cuando el usuario dice **"guarda todo"**, ejecutar automáticamente:
1. Actualizar `sesion_actual.md` con la información más reciente de la sesión.
2. Guardar los prompts del día en un archivo `YYYY-MM-DD_prompts.txt` (ej: `2026-05-09_prompts.txt`) en la raíz del proyecto.
3. Hacer `git add -A` + `git commit` + `git push origin main`.

## 9. Pendientes — Próxima Sesión

1. **Test completo** del flujo: Solicitud → Planificación → Carga → Depósito → Viaje → Pesaje → Remito.
2. **Vincular solicitudes al cerrar remito**: al finalizar parada, cambiar `solicitudes.estado = 'Terminado'`.
3. **Vehículo detalle**: barra de progreso de depósito circulante.
4. **WhatsApp**: el link `wa.me/` debe incluir el teléfono del apicultor precargado.

---
*GeoLogística v1.2.1 — "Roles & Deposito Fix" — 09/05/2026 22:56hs*
