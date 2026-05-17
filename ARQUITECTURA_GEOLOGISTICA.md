# Master Blueprint: Arquitectura y Lógica de GeoLogística
**Versión:** 1.1 (17 de Mayo de 2026)
**Objetivo:** Proveer una guía técnica infalible para la reconstrucción o continuación del proyecto por cualquier IA o desarrollador, garantizando 0 retrocesos.

## 1. Pilares Arquitectónicos
- **Framework:** Flutter (Canal Stable).
- **Backend:** Supabase (PostgreSQL + Realtime + Storage Buckets).
- **Diseño:** "Stitch Premium". Colores: `Deep Forest Green` (#1E302C), `Honey Gold` (#C68E17). Tipografía: Inter/Outfit.
- **Navegación:** `GoRouter` para manejo de pilas y rutas declarativas.

## 2. Estrategias Críticas (No Cambiar)
### A. Autenticación "Bypass" (Estabilidad de Hilo UI)
- **Problema:** El SDK de Supabase Auth causa deadlocks en emuladores Android al usar teclados.
- **Solución:** Se utiliza un sistema de login directo consultando la tabla `profiles`.
- **Implementación:** `SupabaseService.login(email, password)` busca coincidencias exactas en la tabla pública y guarda la sesión en `SharedPreferences`.
- **Importante:** Las pantallas NO deben usar `Supabase.auth.currentUser`. Deben usar el `user_id` guardado localmente.

### B. Gestión de Identidad del Chofer
- **Regla de Oro:** Todas las asignaciones de viajes (`viajes.chofer_id`) DEBEN usar el **UUID** (id de la tabla profiles) y NO el correo electrónico.
- **Impacto:** Si se usa el correo, el rol Chofer no verá sus viajes en el Home y no podrá operar.

### C. Lógica de Estados de Operación
Las solicitudes y viajes siguen un circuito de estados estricto:
1. `Pendiente`: Creada por el apicultor/gerente.
2. `Asignada`: Vinculada a un viaje (parada) pero el viaje no ha iniciado.
3. `En Curso`: El viaje ha sido iniciado por el chofer.
4. `Terminada / Finalizada`: Operación completada con remito generado.

## 3. Estructura de Datos y Relaciones
- **Viajes -> Paradas**: Un viaje tiene múltiples paradas.
- **Paradas -> Solicitudes**: Cada parada está vinculada a una `solicitud_id`.
- **Solicitudes -> Remitos**: Una solicitud terminada se vincula a un remito a través de la parada.
- **Cargas -> Vehículos**: Las cargas actualizan el stock "en circulación" del vehículo (`carga_actual_kg`).

## 4. Dashboard de Apicultor (Módulo Crítico)
- **Archivo:** `lib/pages/apicultor_detalle.dart`.
- **Lógica de Fetch:** Debe buscar solicitudes usando múltiples candidatos de ID (con/sin prefijo 'A', con/sin ceros a la izquierda) para asegurar visibilidad 100%.
- **Resumen:** Se agrupa por producto y se cuenta por estado (Pendientes, Asignadas, En Curso, Terminadas).

## 5. Prevención de Errores Comunes (Checklist)
- [ ] **Cascada de Eliminación**: Al borrar un viaje, limpiar primero `carga_items`, luego `cargas`, luego `parada_items`, luego `paradas`, y finalmente el viaje. Liberar solicitudes (`estado = 'Pendiente'`).
- [ ] **Sintaxis Dart**: Mantener `dart analyze` con 0 errores. Evitar llaves de cierre accidentales que corten clases.
- [ ] **Refresh**: Siempre llamar a `_fetchDetailedData()` o equivalentes después de un `insert/update` para reflejar cambios en la UI.
- [ ] **Null Safety**: Usar `.maybeSingle()` y verificaciones de nulidad en campos como `localidad` y `nombre` (posibles swaps en DB).

## 6. Configuración de Entorno
- **Impeller:** Desactivado en Android para estabilidad gráfica.
- **Java:** JDK 17+ requerido.
- **Variables Supabase:** URL y Key Anon deben estar configuradas en `supabase_service.dart`.

## 7. Logística de Campo Avanzada (Multi-Remito)
### A. Sistema de Remitos Múltiples y Soporte de Terceros (Terceros)
- **Escenario**: Un apicultor responsable de la parada (por ejemplo, Hassel) puede entregar carga propia o de un tercero (por ejemplo, Leandro).
- **Implementación**:
  - En la parte superior de `RemitoRegistroPage`, se provee un selector de **Apicultor Titular del Remito** conectado con un buscador en tiempo real sobre todos los apicultores de la base de datos.
  - Esto desvincula al firmante físico del propietario de los tambores: el titular puede ser **Leandro** (Tercero) y el firmante físico puede ser el chofer o un empleado ("Un Tercero" con su nombre/DNI).
  - Al guardar el remito, la sincronización asocia el remito e impacta los volúmenes directamente en la ficha del **Apicultor Titular** seleccionado, manteniendo la integridad contable.

### B. Pesaje y Reconciliación "En Caliente"
- **Habilitación:** El módulo de pesaje se activa si existe un ítem con código `TCM` en la parada, sin importar la planificación original.
- **Reconciliación:** El sistema prioriza el conteo físico (registros en la tabla `pesajes`) sobre la cantidad planificada en `parada_items`. Al cargar la parada, se sincroniza la cantidad del ítem `TCM` con el conteo de pesajes.
- **Unidades:** Los ítems `TCM` deben usar siempre la unidad `uni` para el conteo individual de tambores.

### C. Firmas Digitales y Generación de PDF (Almacenamiento)
- **Captura**: Se capturan las firmas mediante un lienzo de dibujo y se exportan como PNG (`Uint8List`).
- **Almacenamiento**: No se guardan como cadenas base64 en la base de datos para no saturar las transacciones. En su lugar, se suben al Storage Bucket público de Supabase `remitos` mediante el helper robusto `_uploadFileWithAutoBucket`.
- **Registro**: Se guardan las URLs públicas `firma_url` y `pdf_url` (generadas mediante `Printing` y subidas al Storage) en la fila del remito en la base de datos.

### D. Reseteo de Paradas ("En Blanco" para Remito Continuo)
- **Base de Datos**: Tan pronto como se confirma la emisión del remito actual, se realiza una transacción de limpieza en Supabase: se eliminan físicamente todos los `pesajes` asociados a esa parada y se setean a `0` las cantidades de todos los `parada_items`.
- **Caché de UI**: En el retorno a `ParadaDetalleWidget`, se limpian los controladores locales mediante `_quantityControllers.clear()` y los controladores del receptor. Esto obliga a la interfaz a redibujarse completamente limpia, permitiendo iniciar inmediatamente un nuevo remito de producto.
