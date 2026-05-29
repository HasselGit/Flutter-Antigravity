# Master Blueprint: Arquitectura y LÃ³gica de GeoLogÃ­stica
**VersiÃ³n:** 1.5 (22 de Mayo de 2026)
**Objetivo:** Proveer una guÃ­a tÃ©cnica infalible para la reconstrucciÃ³n o continuaciÃ³n del proyecto por cualquier IA o desarrollador, garantizando 0 retrocesos.

## 1. Pilares ArquitectÃ³nicos
- **Framework:** Flutter (Canal Stable).
- **Backend:** Supabase (PostgreSQL + Realtime + Storage Buckets).
- **DiseÃ±o:** "Stitch Premium". Colores: `Deep Forest Green` (#1E302C), `Honey Gold` (#C68E17). TipografÃ­a: Inter/Outfit.
- **NavegaciÃ³n:** `GoRouter` para manejo de pilas y rutas declarativas.

## 2. Estrategias CrÃ­ticas (No Cambiar)
### A. AutenticaciÃ³n "Bypass" (Estabilidad de Hilo UI)
- **Problema:** El SDK de Supabase Auth causa deadlocks en emuladores Android al usar teclados.
- **SoluciÃ³n:** Se utiliza un sistema de login directo consultando la tabla `profiles`.
- **ImplementaciÃ³n:** `SupabaseService.login(email, password)` busca coincidencias exactas en la tabla pÃºblica y guarda la sesiÃ³n en `SharedPreferences`.
- **Importante:** Las pantallas NO deben usar `Supabase.auth.currentUser`. Deben usar el `user_id` guardado localmente.

### B. GestiÃ³n de Identidad del Chofer
- **Regla de Oro:** Todas las asignaciones de viajes (`viajes.chofer_id`) DEBEN usar el **UUID** (id de la tabla profiles) y NO el correo electrÃ³nico.
- **Impacto:** Si se usa el correo, el rol Chofer no verÃ¡ sus viajes en el Home y no podrÃ¡ operar.

### C. LÃ³gica de Estados de OperaciÃ³n
Las solicitudes y viajes siguen un circuito de estados estricto:
1. `Pendiente`: Creada por el apicultor/gerente.
2. `Asignada`: Vinculada a un viaje (parada) pero el viaje no ha iniciado.
3. `En Curso`: El viaje ha sido iniciado por el chofer.
4. `Terminada / Finalizada`: OperaciÃ³n completada con remito generado.
5. `Eliminada` (Borrado LÃ³gico): Para evitar violaciones de integridad referencial histÃ³rica o fallos de polÃ­ticas RLS, la eliminaciÃ³n de una solicitud actualiza su estado a `'Eliminada'`. Las vistas del planificador, estadÃ­sticas y perfiles las filtran de forma activa.

## 3. Estructura de Datos y Relaciones
- **Viajes -> Paradas**: Un viaje tiene mÃºltiples paradas.
- **Paradas -> Solicitudes**: Cada parada estÃ¡ vinculada a una `solicitud_id`.
- **Solicitudes -> Remitos**: Una solicitud terminada se vincula a un remito a travÃ©s de la parada.
- **Cargas -> VehÃ­culos**: Las cargas actualizan el stock "en circulaciÃ³n" del vehÃ­culo (`carga_actual_kg`).

## 4. Dashboard de Apicultor (MÃ³dulo CrÃ­tico)
- **Archivo:** `lib/pages/apicultor_detalle.dart`.
- **LÃ³gica de Fetch:** Debe buscar solicitudes usando mÃºltiples candidatos de ID (con/sin prefijo 'A', con/sin ceros a la izquierda) para asegurar visibilidad 100%.
- **Resumen:** Se agrupa por producto y se cuenta por estado (Pendientes, Asignadas, En Curso, Terminadas).

## 5. PrevenciÃ³n de Errores Comunes (Checklist)
- [ ] **Cascada de EliminaciÃ³n**: Al borrar un viaje, limpiar primero `carga_items`, luego `cargas`, luego `parada_items`, luego `paradas`, y finalmente el viaje. Liberar solicitudes (`estado = 'Pendiente'`).
- [ ] **Saneamiento de Solicitudes Eliminadas**: Toda consulta que adquiera solicitudes de forma global debe filtrar `.neq('estado', 'Eliminada')` para prevenir persistencias indeseadas en planificadores, dashboards o perfiles de apicultores. **CRÃ�TICO**: `getNecesidadesPendientes()` tambiÃ©n debe incluir `.neq('estado', 'Eliminada')` como doble seguridad, ya que el `.eq('estado', 'Pendiente')` y el `.neq('estado', 'Eliminada')` son redundantes pero necesarios para prevenir edge cases. El planificador al cargar solicitudes ya asignadas a un viaje en ediciÃ³n tambiÃ©n debe filtrar `Eliminadas` explÃ­citamente.
- [ ] **Desbloqueo de Parada en Proceso**: Una parada con estado DB `'Terminada'` pero sin remitos vÃ¡lidos (`remitos.isEmpty`) no debe considerarse de solo lectura para el chofer; esto permite al chofer completar pesajes pendientes y emitir el remito faltante.
- [ ] **Modal Overflow (BottomSheet con Teclado)**: Cuando un `showModalBottomSheet` contiene campos de texto, la tÃ©cnica correcta es: (1) envolver el contenido en `Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom))`, (2) luego en `SafeArea(top: false)`, (3) luego el `Container` con `constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75)`. NUNCA aplicar el padding del teclado directamente al `Container` sin `maxHeight`.
- [ ] **Sintaxis Dart**: Mantener `dart analyze` con 0 errores. Evitar llaves de cierre accidentales que corten clases.
- [ ] **Refresh**: Siempre llamar a `_fetchDetailedData()` o equivalentes despuÃ©s de un `insert/update` para reflejar cambios en la UI.
- [ ] **Null Safety**: Usar `.maybeSingle()` y verificaciones de nulidad en campos como `localidad` y `nombre` (posibles swaps en DB).

## 6. ConfiguraciÃ³n de Entorno
- **Impeller:** Desactivado en Android para estabilidad grÃ¡fica.
- **Java:** JDK 17+ requerido.
- **Variables Supabase:** URL y Key Anon deben estar configuradas en `supabase_service.dart`.

## 7. LogÃ­stica de Campo Avanzada (Multi-Remito)
### A. Sistema de Remitos MÃºltiples y Soporte de Terceros (Terceros)
- **Escenario**: Un apicultor responsable de la parada (por ejemplo, Hassel) puede entregar carga propia o de un tercero (por ejemplo, Leandro).
- **ImplementaciÃ³n**:
  - En la parte superior de `RemitoRegistroPage`, se provee un selector de **Apicultor Titular del Remito** conectado con un buscador en tiempo real sobre todos los apicultores de la base de datos.
  - Esto desvincula al firmante fÃ­sico del propietario de los tambores: el titular puede ser **Leandro** (Tercero) y el firmante fÃ­sico puede ser el chofer o un empleado ("Un Tercero" con su nombre/DNI).
  - Al guardar el remito, la sincronizaciÃ³n asocia el remito e impacta los volÃºmenes directamente en la ficha del **Apicultor Titular** seleccionado, manteniendo la integridad contable.

### B. Pesaje y ReconciliaciÃ³n "En Caliente"
- **HabilitaciÃ³n:** El mÃ³dulo de pesaje se activa si existe un Ã­tem con cÃ³digo `TCM` en la parada, sin importar la planificaciÃ³n original.
- **ReconciliaciÃ³n:** El sistema prioriza el conteo fÃ­sico (registros en la tabla `pesajes`) sobre la cantidad planificada en `parada_items`. Al cargar la parada, se sincroniza la cantidad del Ã­tem `TCM` con el conteo de pesajes.
- **Unidades:** Los Ã­tems `TCM` deben usar siempre la unidad `uni` para el conteo individual de tambores.

### C. Firmas Digitales y GeneraciÃ³n de PDF (Almacenamiento)
- **Captura**: Se capturan las firmas mediante un lienzo de dibujo y se exportan como PNG (`Uint8List`).
- **Almacenamiento**: No se guardan como cadenas base64 en la base de datos para no saturar las transacciones. En su lugar, se suben al Storage Bucket pÃºblico de Supabase `remitos` mediante el helper robusto `_uploadFileWithAutoBucket`.
- **Registro**: Se guardan las URLs pÃºblicas `firma_url` y `pdf_url` (generadas mediante `Printing` y subidas al Storage) en la fila del remito en la base de datos.

### D. PreservaciÃ³n de Cantidades y Remito Continuo
- **ConservaciÃ³n de Datos**: Al confirmarse la firma y emisiÃ³n del remito, **no** se restablecen a `0` las cantidades de `parada_items` ni se eliminan los `pesajes` fÃ­sicos en Supabase. Esto asegura que la pantalla de *Detalle de Viaje* y los resÃºmenes ejecutivos preserven y muestren los valores reales completados en terreno.
- **CachÃ© de UI**: En el retorno a `ParadaDetalleWidget`, los controladores locales se sincronizan y refrescan de forma segura para permitir ediciones o revisiones del estado de entrega.

## 8. Dashboard Premium & Eliminaciones en Cascada (CEO/Gerencia)
- **Panel Ejecutivo Premium**: En `homepage.dart`, se ocultan condicionalmente los accesos operacionales (`GestiÃ³n de Cargas`, `Control Pesajes`, `Gastos`, `Productos`) para roles directivos (`CEO`, `Gerente`, `Gerencia`), presentÃ¡ndoles una interfaz ejecutiva pura de KPIs.
- **NavegaciÃ³n Interactiva**: En `gerentehome.dart`, las tarjetas de Distribuciones y Recolecciones estÃ¡n enlazadas mediante animaciones de respuesta tÃ¡ctil (`InkWell` con chevrons) para redirigir fluidamente a `/recolecciones` y `/distribuciones`.
- **Bypass de CodificaciÃ³n de Caracteres**: Las estadÃ­sticas del CEO calculan Distribuciones y Recolecciones en tiempo real mediante comparaciones de subcadena parciales (`tipo.contains('recol')` y `tipo.contains('distrib')`), previniendo que discrepancias de codificaciÃ³n (`RecolecciÃ³n` vs `Recoleccin` en Supabase) congelen los contadores en `0`.
- **Cascada Inteligente de Solicitudes**: Al eliminar una solicitud desde el panel, el sistema realiza una limpieza profunda y transaccional sobre `parada_items`, `pesajes` y `remitos`. Si el viaje estÃ¡ en estado `Pendiente`, la solicitud es liberada al planificador volviendo de estado `Asignada` a `Pendiente`.

## 9. Equivalencia de Productos de Terreno (TCM / 1)
- **ConciliaciÃ³n de CÃ³digos**: Los conductores registran los pesajes de tambores utilizando el cÃ³digo numÃ©rico `'1'`, mientras que el sistema administrativo procesa `'TCM'`.
- **LÃ³gica de Mapeo**: Se implementÃ³ una lÃ³gica de equivalencia bidireccional en las pantallas y validaciones clave (`remito_registro.dart`, `paradadetalle.dart` y `viaje_detalle.dart`). Ambas claves se consideran idÃ©nticas al sumar existencias, consolidar pesos y renderizar la interfaz.

## 10. Permisos de Super-Administrador (hassel00@gmail.com)
- **IdentificaciÃ³n**: El administrador se identifica por su email de Supabase Auth: `hassel00@gmail.com`. Se obtiene en runtime mediante `Supabase.instance.client.auth.currentUser?.email`.
- **Getter estÃ¡ndar**: En cada pÃ¡gina que necesite permisos extendidos usar: `bool get _isAdmin => Supabase.instance.client.auth.currentUser?.email == 'hassel00@gmail.com';`
- **Capacidades exclusivas del Admin**:
  - Editar y eliminar viajes en **cualquier estado** (incluyendo `Terminado`), a diferencia de otros roles que solo pueden en `Pendiente`/`En Proceso`.
  - Navegar a paradas de viajes `Terminados` (otros usuarios ven las tarjetas como no-tapeables).
  - Eliminar remitos individuales de una parada. Al eliminar, el sistema restablece `parada.estado = 'En Proceso'` y `parada.remito_id = null`, dejando la parada editable para regenerar el remito. MÃ©todo: `SupabaseService().deleteRemito(remitoId, paradaId)`.
  - En `ParadaDetalleWidget`, `isReadOnly = false` siempre para el admin, independientemente del estado de la parada o el viaje.

## 11. SincronizaciÃ³n con Google Sheets
- **Estado actual**: La sincronizaciÃ³n con Google Sheets es **manual**, no automÃ¡tica. Se realiza ejecutando el script `scratch/sync_sheets_to_supabase.dart` desde la terminal cuando se cargan nuevos apicultores en el Sheet.
- **Sheet ID**: `1vcg7nmkTfp_AyTTkTOGuGu7k-B2eAAUA_V8P24wa1Es` (hoja `gid=1388406787`).
- **Mecanismo**: El script descarga el Sheet como CSV y hace `upsert` en la tabla `apicultores` de Supabase.
- **Pendiente**: Integrar un botÃ³n de sincronizaciÃ³n manual en la UI del admin, o bien disparar la sincronizaciÃ³n en segundo plano al iniciar sesiÃ³n como `hassel00@gmail.com`.

## 12. Salvaguarda de Cargas VacÃ­as y Doble Capa RLS (Supabase)
- **Problema de JWT Stale**: El uso de emuladores y pruebas repetidas puede persistir tokens de Supabase Auth nativos obsoletos en `flutter_secure_storage`. Esto fuerza las consultas relacionales del backend bajo el rol `authenticated`, activando filtros RLS que silencian las filas de `carga_items` y muestran "0 items / 0 kg" de forma errÃ³nea (ej. `CARGA-7845001`).
- **Limpieza Preventiva en UI**: En pantallas crÃ­ticas de depÃ³sito (`depositohome.dart`), se ejecuta `await Supabase.instance.client.auth.signOut()` de manera preventiva en la inicializaciÃ³n (`_fetchData()`) para limpiar el hilo local de tokens persistidos obsoletos y asegurar llamadas con rol pÃºblico.
- **Fallback Directo en Consultas**: Los mÃ©todos de `SupabaseService` (`getViajeDetalle`, `getTerminatedCargas`, `getCargas`, `getCargaDetalle`) incorporan una doble capa de seguridad: si la consulta relacional con joins devuelve una lista vacÃ­a de `carga_items`, se realiza una consulta directa especÃ­fica a `carga_items` filtrada por `carga_id` para recuperar y re-inyectar los datos reales.

## 13. GeolocalizaciÃ³n e Inteligencia de Direcciones en Google Maps
- **Direcciones FÃ­sicas en Waypoints**: Para evitar bÃºsquedas fallidas y crashes en Google Maps causados por enviar nombres de apicultores como puntos de parada (ej: "No results for General Pico, La Pampa"), se reestructurÃ³ la codificaciÃ³n de waypoints.
- **Formato EstÃ¡ndar**: Las URLs de mapas se generan estrictamente bajo el formato limpio: `"$localidad, $provincia, Argentina"`.
- **ResoluciÃ³n DinÃ¡mica de Provincia**: Se implementÃ³ una lÃ³gica de fallback de provincias. Para cada parada, el sistema busca el nombre del apicultor en `ApicultoresData.fallbackApicultores`. Si existe coincidencia, se extrae su provincia fÃ­sica real; de lo contrario, se asume `'La Pampa'` por defecto.
- **Lanzamiento de Mapas Nativo**: La URL con waypoints codificados en URI se dispara utilizando `launchUrl` en modo `LaunchMode.externalApplication`, forzando la apertura de la aplicaciÃ³n nativa del dispositivo.

## 14. NavegaciÃ³n a Detalle de Viaje desde Necesidades (`/necesidades`)
- **Acceso de AuditorÃ­a y Roles**: Para permitir que roles no operacionales (CEO, DepÃ³sito, Compras) inspeccionen los recorridos y pesajes de viaje de forma fluida, se habilitÃ³ la navegaciÃ³n desde el listado de necesidades.
- **Mapeo de Relaciones**: Durante `_fetchData()` en `necesidades_page.dart`, se consulta la tabla `paradas` para mapear de forma reactiva `solicitud_id -> viaje_id` en el mapa de lookup `_solicitudToViaje`.
- **Interactividad Premium**: Las tarjetas de necesidades en estado `'Asignada'` o `'En Curso'` muestran un chevron colorido (`DesignTokens.primary`) e implementan un `onTap` que redirige a `/viajedetalle?viajeId=X`.
- **Control de Solo Lectura**: La vista `/viajedetalle` evalÃºa dinÃ¡micamente si el rol del usuario no es operativo para ocultar todos los botones de acciÃ³n fÃ­sica, previniendo crashes y manipulaciones indebidas.

## 15. PrevenciÃ³n de Crashes de TamaÃ±o Infinito en Flex Grids
- **Regla de RestricciÃ³n de Ancho en Row/Column**: Los errores de desbordamiento grÃ¡fico (`RenderFlex` overflow o box constraints error) ocurren al anidar filas o columnas flexibles sin delimitar sus tamaÃ±os.
- **SoluciÃ³n en Tarjetas de Viaje (`viajes_page.dart`)**:
  1. Configurar siempre `mainAxisSize: MainAxisSize.min` en filas de botones de acciÃ³n o elementos anidados del lado derecho.
  2. Envolver columnas o textos descriptivos del lado izquierdo en widgets `Expanded` y aplicar control de overflow mediante `overflow: TextOverflow.ellipsis` para evitar desbordamientos en pantallas estrechas.

## 16. Splash Screen Premium e HÃ­brida Imperceptible
- **Problema de Salto Visual**: En muchas apps, la pantalla de Splash y la pantalla de Bienvenido tienen discrepancias de coordenadas de logo y fondos de color, provocando saltos bruscos y molestos para el usuario.
- **SoluciÃ³n de DiseÃ±o Unificado**: En `welcomepage.dart`, implementamos ambas etapas en un Ãºnico widget de estado. El fondo es gestionado por un `AnimatedContainer` que se inicia en blanco puro (`Colors.white`) para mimetizarse perfectamente con el fondo original del logo, y transiciona suavemente en 800ms hacia `theme.primaryBackground` cuando el splash termina.
# Master Blueprint: Arquitectura y Lógica de GeoLogística
**Versión:** 1.5 (22 de Mayo de 2026)
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
5. `Eliminada` (Borrado Lógico): Para evitar violaciones de integridad referencial histórica o fallos de políticas RLS, la eliminación de una solicitud actualiza su estado a `'Eliminada'`. Las vistas del planificador, estadísticas y perfiles las filtran de forma activa.

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
- [ ] **Saneamiento de Solicitudes Eliminadas**: Toda consulta que adquiera solicitudes de forma global debe filtrar `.neq('estado', 'Eliminada')` para prevenir persistencias indeseadas en planificadores, dashboards o perfiles de apicultores. **CRÍTICO**: `getNecesidadesPendientes()` también debe incluir `.neq('estado', 'Eliminada')` como doble seguridad, ya que el `.eq('estado', 'Pendiente')` y el `.neq('estado', 'Eliminada')` son redundantes pero necesarios para prevenir edge cases. El planificador al cargar solicitudes ya asignadas a un viaje en edición también debe filtrar `Eliminadas` explícitamente.
- [ ] **Desbloqueo de Parada en Proceso**: Una parada con estado DB `'Terminada'` pero sin remitos válidos (`remitos.isEmpty`) no debe considerarse de solo lectura para el chofer; esto permite al chofer completar pesajes pendientes y emitir el remito faltante.
- [ ] **Modal Overflow (BottomSheet con Teclado)**: Cuando un `showModalBottomSheet` contiene campos de texto, la técnica correcta es: (1) envolver el contenido en `Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom))`, (2) luego en `SafeArea(top: false)`, (3) luego el `Container` con `constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75)`. NUNCA aplicar el padding del teclado directamente al `Container` sin `maxHeight`.
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

### D. Preservación de Cantidades y Remito Continuo
- **Conservación de Datos**: Al confirmarse la firma y emisión del remito, **no** se restablecen a `0` las cantidades de `parada_items` ni se eliminan los `pesajes` físicos en Supabase. Esto asegura que la pantalla de *Detalle de Viaje* y los resúmenes ejecutivos preserven y muestren los valores reales completados en terreno.
- **Caché de UI**: En el retorno a `ParadaDetalleWidget`, los controladores locales se sincronizan y refrescan de forma segura para permitir ediciones o revisiones del estado de entrega.

## 8. Dashboard Premium & Eliminaciones en Cascada (CEO/Gerencia)
- **Panel Ejecutivo Premium**: En `homepage.dart`, se ocultan condicionalmente los accesos operacionales (`Gestión de Cargas`, `Control Pesajes`, `Gastos`, `Productos`) para roles directivos (`CEO`, `Gerente`, `Gerencia`), presentándoles una interfaz ejecutiva pura de KPIs.
- **Navegación Interactiva**: En `gerentehome.dart`, las tarjetas de Distribuciones y Recolecciones están enlazadas mediante animaciones de respuesta táctil (`InkWell` con chevrons) para redirigir fluidamente a `/recolecciones` y `/distribuciones`.
- **Bypass de Codificación de Caracteres**: Las estadísticas del CEO calculan Distribuciones y Recolecciones en tiempo real mediante comparaciones de subcadena parciales (`tipo.contains('recol')` y `tipo.contains('distrib')`), previniendo que discrepancias de codificación (`Recolección` vs `Recoleccin` en Supabase) congelen los contadores en `0`.
- **Cascada Inteligente de Solicitudes**: Al eliminar una solicitud desde el panel, el sistema realiza una limpieza profunda y transaccional sobre `parada_items`, `pesajes` y `remitos`. Si el viaje está en estado `Pendiente`, la solicitud es liberada al planificador volviendo de estado `Asignada` a `Pendiente`.

## 9. Equivalencia de Productos de Terreno (TCM / 1)
- **Conciliación de Códigos**: Los conductores registran los pesajes de tambores utilizando el código numérico `'1'`, mientras que el sistema administrativo procesa `'TCM'`.
- **Lógica de Mapeo**: Se implementó una lógica de equivalencia bidireccional en las pantallas y validaciones clave (`remito_registro.dart`, `paradadetalle.dart` y `viaje_detalle.dart`). Ambas claves se consideran idénticas al sumar existencias, consolidar pesos y renderizar la interfaz.

## 10. Permisos de Super-Administrador (hassel00@gmail.com)
- **Identificación**: El administrador se identifica por su email de Supabase Auth: `hassel00@gmail.com`. Se obtiene en runtime mediante `Supabase.instance.client.auth.currentUser?.email`.
- **Getter estándar**: En cada página que necesite permisos extendidos usar: `bool get _isAdmin => Supabase.instance.client.auth.currentUser?.email == 'hassel00@gmail.com';`
- **Capacidades exclusivas del Admin**:
  - Editar y eliminar viajes en **cualquier estado** (incluyendo `Terminado`), a diferencia de otros roles que solo pueden en `Pendiente`/`En Proceso`.
  - Navegar a paradas de viajes `Terminados` (otros usuarios ven las tarjetas como no-tapeables).
  - Eliminar remitos individuales de una parada. Al eliminar, el sistema restablece `parada.estado = 'En Proceso'` y `parada.remito_id = null`, dejando la parada editable para regenerar el remito. Método: `SupabaseService().deleteRemito(remitoId, paradaId)`.
  - En `ParadaDetalleWidget`, `isReadOnly = false` siempre para el admin, independientemente del estado de la parada o el viaje.

## 11. Sincronización con Google Sheets
- **Estado actual**: La sincronización con Google Sheets es **manual**, no automática. Se realiza ejecutando el script `scratch/sync_sheets_to_supabase.dart` desde la terminal cuando se cargan nuevos apicultores en el Sheet.
- **Sheet ID**: `1vcg7nmkTfp_AyTTkTOGuGu7k-B2eAAUA_V8P24wa1Es` (hoja `gid=1388406787`).
- **Mecanismo**: El script descarga el Sheet como CSV y hace `upsert` en la tabla `apicultores` de Supabase.
- **Pendiente**: Integrar un botón de sincronización manual en la UI del admin, o bien disparar la sincronización en segundo plano al iniciar sesión como `hassel00@gmail.com`.

## 12. Salvaguarda de Cargas Vacías y Doble Capa RLS (Supabase)
- **Problema de JWT Stale**: El uso de emuladores y pruebas repetidas puede persistir tokens de Supabase Auth nativos obsoletos en `flutter_secure_storage`. Esto fuerza las consultas relacionales del backend bajo el rol `authenticated`, activando filtros RLS que silencian las filas de `carga_items` y muestran "0 items / 0 kg" de forma errónea (ej. `CARGA-7845001`).
- **Limpieza Preventiva en UI**: En pantallas críticas de depósito (`depositohome.dart`), se ejecuta `await Supabase.instance.client.auth.signOut()` de manera preventiva en la inicialización (`_fetchData()`) para limpiar el hilo local de tokens persistidos obsoletos y asegurar llamadas con rol público.
- **Fallback Directo en Consultas**: Los métodos de `SupabaseService` (`getViajeDetalle`, `getTerminatedCargas`, `getCargas`, `getCargaDetalle`) incorporan una doble capa de seguridad: si la consulta relacional con joins devuelve una lista vacía de `carga_items`, se realiza una consulta directa específica a `carga_items` filtrada por `carga_id` para recuperar y re-inyectar los datos reales.

## 13. Geolocalización e Inteligencia de Direcciones en Google Maps
- **Direcciones Físicas en Waypoints**: Para evitar búsquedas fallidas y crashes en Google Maps causados por enviar nombres de apicultores como puntos de parada (ej: "No results for General Pico, La Pampa"), se reestructuró la codificación de waypoints.
- **Formato Estándar**: Las URLs de mapas se generan estrictamente bajo el formato limpio: `"$localidad, $provincia, Argentina"`.
- **Resolución Dinámica de Provincia**: Se implementó una lógica de fallback de provincias. Para cada parada, el sistema busca el nombre del apicultor en `ApicultoresData.fallbackApicultores`. Si existe coincidencia, se extrae su provincia física real; de lo contrario, se asume `'La Pampa'` por defecto.
- **Lanzamiento de Mapas Nativo**: La URL con waypoints codificados en URI se dispara utilizando `launchUrl` en modo `LaunchMode.externalApplication`, forzando la apertura de la aplicación nativa del dispositivo.

## 14. Navegación a Detalle de Viaje desde Necesidades (`/necesidades`)
- **Acceso de Auditoría y Roles**: Para permitir que roles no operacionales (CEO, Depósito, Compras) inspeccionen los recorridos y pesajes de viaje de forma fluida, se habilitó la navegación desde el listado de necesidades.
- **Mapeo de Relaciones**: Durante `_fetchData()` en `necesidades_page.dart`, se consulta la tabla `paradas` para mapear de forma reactiva `solicitud_id -> viaje_id` en el mapa de lookup `_solicitudToViaje`.
- **Interactividad Premium**: Las tarjetas de necesidades en estado `'Asignada'` o `'En Curso'` muestran un chevron colorido (`DesignTokens.primary`) e implementan un `onTap` que redirige a `/viajedetalle?viajeId=X`.
- **Control de Solo Lectura**: La vista `/viajedetalle` evalúa dinámicamente si el rol del usuario no es operativo para ocultar todos los botones de acción física, previniendo crashes y manipulaciones indebidas.

## 15. Prevención de Crashes de Tamaño Infinito en Flex Grids
- **Regla de Restricción de Ancho en Row/Column**: Los errores de desbordamiento gráfico (`RenderFlex` overflow o box constraints error) ocurren al anidar filas o columnas flexibles sin delimitar sus tamaños.
- **Solución en Tarjetas de Viaje (`viajes_page.dart`)**:
  1. Configurar siempre `mainAxisSize: MainAxisSize.min` en filas de botones de acción o elementos anidados del lado derecho.
  2. Envolver columnas o textos descriptivos del lado izquierdo en widgets `Expanded` y aplicar control de overflow mediante `overflow: TextOverflow.ellipsis` para evitar desbordamientos en pantallas estrechas.

## 16. Splash Screen Premium e Híbrida Imperceptible
- **Problema de Salto Visual**: En muchas apps, la pantalla de Splash y la pantalla de Bienvenido tienen discrepancias de coordenadas de logo y fondos de color, provocando saltos bruscos y molestos para el usuario.
- **Solución de Diseño Unificado**: En `welcomepage.dart`, implementamos ambas etapas en un único widget de estado. El fondo es gestionado por un `AnimatedContainer` que se inicia en blanco puro (`Colors.white`) para mimetizarse perfectamente con el fondo original del logo, y transiciona suavemente en 800ms hacia `theme.primaryBackground` cuando el splash termina.
- **Efecto de Respiración Continua e Interrupción**: Se utiliza un `AnimationController` que oscila la escala del logo de `1.0` a `1.06` en curva de desaceleración. Para evitar que el listener entre en un bucle infinito en su estado `dismissed` al detenerse, se agregó una bandera de verificación (`if (!_isSplashActive) return;`), deteniendo la animación limpiamente en su tamaño original (`1.0`) y dejándolo estable.
- **Transición de Desvanecimiento por Bloques**: La barra Honey Gold (`#C68E17`) e indicadoras del Splash se ocultan con `AnimatedOpacity`, y el resto de la interfaz (Títulos, Eslogan y Botón INICIAR) se despliegan en el mismo espacio con retardo de fade-in de 800ms, manteniendo el logo estático en su lugar geométrico original.
- **Inmersión del Status Bar**: Para evitar el antiestético bloque horizontal gris oscuro que por defecto pinta Android en el área superior del status bar, se configuró globalmente en `main.dart` el uso de `SystemChrome.setSystemUIOverlayStyle` con `statusBarColor: Colors.transparent` e íconos en `Brightness.dark`. Esto extiende el lienzo de dibujo y el patrón honeycomb hasta el extremo físico superior del dispositivo.

## 17. Declaración de Visibilidad del Sistema de Intents (Android 11+)
- **Problema de Bloqueo de Hardware**: Las apps modernas Android (SDK 30+) bloquean la resolución e invocación de intents externos (como la cámara o visor de fotos) a menos que se declaren explícitamente en el manifest.
- **Solución en Manifest**: Se agregó la acción del intent `android.media.action.IMAGE_CAPTURE` dentro de la sección `<queries>` de `AndroidManifest.xml` para garantizar la compatibilidad universal del plugin de selección de fotos en el formulario de gastos.

## 18. Auto-Finalización, Auto-Sanación de Rutas y Doble WhatsApp Fallback
- **Auto-Finalización en Distribución**: Las paradas de tipo `DistribuciÃ³n` se auto-finalizan en Supabase al momento de la firma electrónica y guardado del remito único, reduciendo la fricción para el conductor.
- **Auto-Sanación Reactiva**: Al consultar `getViajeDetalle` en `supabase_service.dart`, el backend compara si existen paradas en estado `'Pendiente'` que cuenten con remitos en base de datos. Si las detecta, actualiza el estado de las paradas a `'Terminado'` y recalcula el inventario del camión sobre la marcha para asegurar la visualización y habilitación del botón verde **"FINALIZAR VIAJE"**.
- **Lookup y Actualización de Apicultores**: Si el apicultor no cuenta con un número celular registrado, el sistema busca coincidencias en `ApicultoresData.fallbackApicultores`. Si el usuario ingresa o corrige su teléfono en la firma digital, este se actualiza inmediatamente en Supabase (tabla `apicultores`) para futuras referencias.
- **WhatsApp Dual-Scheme**: El sistema intenta lanzar primero el intent nativo `whatsapp://send?phone=...`. Si falla (ej. emulador), atrapa la excepción y lanza la versión web `web.whatsapp.com` en el navegador del dispositivo de forma transparente.

## 19. Optimización de Cargas y Control Proyectado de Capacidad (Cargas/Tránsito)
- **Control de Stock en Tránsito en Ruta**: Mapea en caliente la cantidad de insumos actualmente en tránsito en el camión. Se calcula sumando la carga inicial asignada y las recolecciones finalizadas en ruta, restando las entregas realizadas. Si el chofer intenta registrar una entrega que exceda el stock disponible del camión, el sistema lo bloquea en `agregaritem.dart` con una SnackBar descriptiva.
- **Validación Proyectada de Capacidad del Vehículo (Peso Camión)**: Evalúa dinámicamente el peso proyectado del camión sumando y restando los pesos dinámicos de los productos del catálogo de base de datos (`peso_unit_kg` en la tabla `productos`). Esta validación bloquea de manera predictiva cualquier carga inicial en depósito (`depositohome.dart`) o adición de ítems en ruta (`agregaritem.dart`) si el peso proyectado supera la capacidad máxima declarada del vehículo (`capacidad_kg`).
- **Pre-población de Cargas en Depósito basada en Planificación**: En el diálogo de asignación de carga de depósito (`_showAddCargaDialog`), al seleccionar un viaje, el sistema realiza una consulta en segundo plano de las paradas de tipo "Distribución", consolida la demanda planificada y pre-pobla el formulario automáticamente como chips visuales interactivos y un interruptor de autocompletado habilitado por defecto.
- **Acceso Ejecutivo Sincronizado**: Los roles de Compras, CEO y Gerente (`_isManagement`) disponen de visualización y navegación cruzada al panel de cargas de depósito. Se habilitaron las estadísticas dinámicas en el panel de inicio, la tarjeta de módulo en el grid principal y el acceso directo del drawer lateral hacia `/depositoHome`.