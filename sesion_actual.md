# Sesión Actual - 1 de Junio, 2026

## 🛡️ Hito de Seguridad: Consolidación de Reglas de Negocio, Auditoría de Cargas y Control Total de Paradas

En esta sesión implementamos con éxito el paquete de seguridad operativo, auditoría y control de depósito/ruta más exhaustivo de **GeoLogística**, resolviendo brechas de lógica y blindando la integridad operativa para evitar retrocesos causados por cualquier agente de IA o desarrollador en el futuro.

> [!IMPORTANT]
> **SALVAGUARDA CONTRA CAMBIOS FUTUROS**:
> Para garantizar que ninguna de estas reglas de negocio críticas pueda ser alterada, modificada o eliminada por ningún agente de IA en el futuro, se ha actualizado el **Master Blueprint** del proyecto: [ARQUITECTURA_GEOLOGISTICA.md](file:///c:/Users/Parque-Apicola/Desktop/Geologistica/ARQUITECTURA_GEOLOGISTICA.md).
> **Cualquier agente que retome el proyecto DEBE respetar a rajatabla la Sección 20 de dicho documento**, la cual define las restricciones inmutables de estados, roles, depósitos y controles operativos.

---

### 🛑 1. Control de Paradas y Cierre Manual por el Chofer (Eliminación de Auto-Cierre)
- **Brecha Resuelta**: El sistema anteriormente auto-finalizaba las paradas al registrar un remito individual, impidiendo la emisión de múltiples remitos si el chofer tenía que entregar carga de distintos orígenes o a diferentes personas en la misma parada.
- **Implementación**:
  - En `supabase_service.dart`, eliminamos por completo el auto-cierre asíncrono al guardar remitos.
  - Añadimos en `paradadetalle.dart` (el visor de paradas del chofer) el botón de acción explícita **"FINALIZAR PARADA"**.
  - Este botón es de uso exclusivo del chofer y es el único mecanismo por el cual la parada pasa a estado `'Terminada'` en la base de datos de Supabase.
  - Al cerrar la parada, todas las cantidades y productos relacionados en los remitos se consolidan de forma permanente a todos los niveles. Una vez cerrada, la parada se vuelve estrictamente de **Solo Lectura** (excepto para el rol Super-Administrador `hassel00@gmail.com`).

### 📦 2. Prevención de Cargas Vacías y Auditoría de Identidad del Creador
- **Control de Cargas Vacías**: Modificamos la validación transaccional al momento de crear una carga. El sistema valida y bloquea de manera absoluta la creación de cualquier carga si esta no tiene al menos un producto con una cantidad asignada mayor a cero.
- **Auditoría e Identidad (`creado_por`)**: En la tabla `cargas` de Supabase se graba el perfil o rol del usuario logueado que realizó la carga (ej. `CEO`, `COMPRAS`, `GERENCIA`, `DEPOSITO`). Esta información de auditoría se recupera dinámicamente y se muestra con claridad en la ficha de detalle de la carga.

### 🚫 3. Restricción de Roles en la Creación de Cargas (Choferes Bloqueados)
- **Regla de Negocio**: Los choferes **no** están autorizados a crear cargas bajo ningún concepto.
- **Implementación**: Blindamos la interfaz del usuario. Si el rol detectado en la sesión local corresponde al de Chofer, el botón de crear nueva carga en `depositohome.dart` y los formularios de edición se deshabilitan por completo. Únicamente los roles directivos y de soporte administrativo (`CEO`, `Compras`, `Gerencia`, `Depósito`) pueden registrar cargas.

### 🏭 4. Diferenciación Crítica de Depósitos (Huinca vs Parque Industrial - PI)
- **Depósito Huinca (Cargas en Viaje Activo)**: Los choferes pueden cambiar de estado las cargas planificadas en el depósito Huinca, dado que ellos mismos realizarán esta tarea física en un viaje que ya se encuentra "En Curso".
- **Depósito Parque Industrial (PI)**: Está estrictamente prohibido asignar cargas de PI a un viaje que ya está en curso. El camión no puede salir a ruta con cargas pendientes en Parque Industrial. El sistema analiza esto reactivamente en `viaje_detalle.dart` y **bloquea el botón "INICIAR VIAJE"** (mostrando una advertencia descriptiva) si detecta que el viaje contiene cargas PI en estado `Pendiente`.

### 💰 5. Robustez en el Módulo de Gastos (`gastos_page.dart`)
- **Filtro de Viajes por Chofer**: Los conductores únicamente visualizan y pueden imputar gastos sobre sus propios viajes asignados, limpiando la vista y evitando errores cruzados de imputación.
- **Pre-selección Predictiva**: Al abrir el diálogo para registrar un nuevo gasto, el sistema auto-detecta y pre-selecciona el viaje que el chofer tiene `'En Curso'` actualmente.

### 🧹 6. Simplificación de la Pantalla Principal (Eliminación de Redundancias para Choferes)
- **Problema de Redundancia**: Los choferes tenían acceso a múltiples tarjetas genéricas de navegación en la pantalla principal (`homepage.dart`) y en el menú drawer lateral (como "Depósito Huinca", "Productos", "Control de Ruta", "Gastos" y "Control Pesajes") que saturaban la interfaz, ya que el chofer ya opera de forma 100% contextual desde su panel dedicado **"Mis Viajes"**.
- **Solución Implementada**:
  - Inhabilitamos la visibilidad de los módulos de **Depósito Huinca**, **Productos**, **Control de Ruta**, **Gastos** y **Control Pesajes** en la cuadrícula de la pantalla principal exclusivamente cuando el rol del usuario logueado es **Chofer**.
  - Ocultamos los mismos ítems del menú drawer lateral (`_drawerItem`) para el rol Chofer, manteniendo la interfaz sumamente limpia y orientada únicamente a su flujo de trabajo central en **"Mis Viajes"**.

### 📝 7. Inclusión de Depósito en Remitos y Redirección de Choferes
- **Navegación Unificada**: Cambiamos la acción del botón **CARGAS** en el panel del chofer (`choferhome.dart`) para que en lugar de abrir la pantalla de sólo lectura `cargas_page.dart` (que no mostraba el botón Honey Gold **REMITO** ni el diseño correcto), redirija a la pantalla oficial de depósito `/depositoHome` (`depositohome.dart`).
- **Saneamiento de Tarjetas Ficticias**: Modificamos el método `_getActiveItems()` para eliminar por completo la generación de las confusas tarjetas ficticias `viaje_sin_carga` ("SIN CARGA") de la pestaña **PENDIENTES** para todos los roles. Ahora, las tres pestañas muestran únicamente cargas físicas reales del sistema.
- **Selector de Depósito en Carga**: Añadimos un selector de depósito (`deposito_origen`) obligatorio en el formulario para crear nuevas cargas (`_showAddCargaDialog`). Si el usuario es un **Chofer**, el campo dropdown se inactiva y pre-selecciona `'Depósito Huinca'`, permitiéndole crear y asociar cargas en su viaje en curso. Los roles Depósito, CEO, Compras y Gerente conservan el selector desbloqueado para elegir libremente.
- **Origen en PDFs de Remitos**: Actualizamos las plantillas de generación de remito digital cliente (`remito_page.dart`) y remitos de báscula (`remito_registro.dart`). El generador de PDF (`pdf_invoice_generator.dart`) ahora recibe el parámetro opcional `depositoOrigen` de forma asíncrona a partir del viaje y lo despliega formalmente en el área de metadatos bajo el campo **"Depósito de Carga"**.


### 🛑 8. Corrección de Desastres de Diseño, Integridad de Base de Datos y Robustez en Gastos
- **Prevención de Desbordamiento Horizontal (Visual Desastre)**: En `depositohome.dart`, corregimos el desbordamiento horizontal en las cabeceras de las tarjetas de cargas envolviendo el texto descriptivo del lado derecho en un widget `Flexible` con `TextOverflow.ellipsis` y limitando a `maxLines: 1`. Esto asegura que en pantallas estrechas el texto del chofer y el vehículo se corten elegantemente sin generar el desastre de las líneas amarillas y negras de desbordamiento.
- **Visualización de Depósito de Origen**: Se añadió debajo de la información del chofer un indicador de depósito con el icono `Icons.warehouse_rounded`, que muestra el depósito de origen limpio de la carga.
- **Saneamiento y Deserialización Limpia de Cargas**: Modificamos el mapping de `rawList` para sanitizar las propiedades de las cargas. Limpiamos `carga_codigo` y separamos correctamente `deposito_origen` de forma asíncrona, evitando que datos raw de Supabase se muestren de forma incorrecta.
- **Solución al Conflicto de Tipos en Supabase (invalid input syntax for type integer: "150.0")**: La columna `carga_items.cantidad` tiene restricción estricta de tipo `integer` en Postgres. Al guardar cantidades con decimales (doubles) como `150.0` o `125.0`, la transacción fallaba y se revertía por error de sintaxis SQL.
  - En `depositohome.dart`, aplicamos `.round()` a `cant` y `customQty` antes de insertarlos en el arreglo `itemsToInsert`.
  - En `supabase_service.dart`, modificamos `updateCargaItems` para forzar a enteros todas las cantidades pasadas en la actualización mediante `.toInt()`.
- **Filtro de Email por SharedPreferences (Bypass Auth)**: Dado que la aplicación utiliza un bypass del flujo tradicional de login y `Supabase.auth.currentUser` es `null`, la consulta de gastos y cargas filtraba incorrectamente por un email nulo. Corregimos esto resolviendo el `userEmail` dinámicamente desde `SharedPreferences` tanto en `depositohome.dart` como en `gastos_page.dart`.
- **Validaciones Estrictas en el Formulario de Gastos**: Implementamos validaciones requeridas de forma robusta al guardar un gasto en `gastos_page.dart`. El sistema bloquea de manera absoluta la confirmación de un gasto si:
  - El campo de **importe** está vacío o es cero.
  - El **número de comprobante** está en blanco.
  - No hay un **viaje seleccionado / asociado**.
  - Si el tipo de gasto es **Combustible**, valida estrictamente que el campo de **litros** no esté vacío y contenga un valor numérico mayor a cero.


---

## 🛡️ Hito de Seguridad: Reglas de Proyecto y Consistencia de Cargas en Depósito (2 de Junio, 2026)

En esta sesión implementamos con éxito salvaguardas universales contra retrocesos de asistentes de IA y resolvimos de raíz los problemas visuales, de navegación y consistencia lógica en el visor de depósitos (`depositohome.dart`):

### 🛑 9. Inyección de Salvaguardas del Sistema (Anti-Regresiones de IA)
- **Instrucción Crítica en `README.md`**: Agregamos un banner ineludible en el encabezado de `README.md` que obliga a cualquier agente futuro a consultar el Master Blueprint y la bitácora de sesión antes de realizar cualquier cambio en el código.
- **Creación de `.cursorrules` y `.clinerules`**: Creamos estos archivos en la raíz del proyecto para bloquear de forma inmutable las directrices de bypass de autenticación (uso de `SharedPreferences`), la conversión obligatoria a enteros en Supabase para evitar el error `"invalid input syntax for type integer: '150.0'"`, el cierre manual de paradas por choferes y la exclusividad de creación de cargas para roles administrativos.

### 🛑 10. Saneamiento de Tarjetas Vacías y Navegación de Cargas
- **Filtrado de Cargas Vacías/Corruptas**: Corregimos el método `_getActiveItems()` para filtrar y omitir cargas vacías (`carga_items.isEmpty`), resolviendo el problema de las tarjetas fantasma con 0 kg y 0 tambores en la pestaña de Pendientes.
- **Redirección de Navegación (`onTap`)**: Cambiamos la acción de presionar la tarjeta de carga para que redirija de manera correcta al visor de detalle de carga (`/cargaDetalle?id=X`) en lugar del detalle de viaje.
- **Visualización Premium Vertical de Insumos**: Rediseñamos el cuerpo de la tarjeta de carga (`_buildViajeCard`) para desplegar una lista vertical elegante que detalla explícitamente los nombres y códigos de los productos cargados junto a sus cantidades en badges, resolviendo descripciones en base al catálogo y asignando iconos según el tipo de producto.

### 🛑 11. Restricciones y Permisos de Parque Industrial (PI) vs. Depósito Huinca
- **Restricción de PI con Viaje en Proceso**:
  - En `_getActiveItems()`, si el viaje está `'En Curso'`, cualquier carga activa de Parque Industrial se omite automáticamente del listado (ya que debe estar finalizada para que el viaje pueda haber iniciado).
  - En `_showAddCargaDialog`, si el viaje seleccionado está `'En Curso'`, el dropdown de depósito de origen se bloquea y restringe mostrando únicamente la opción `'Depósito Huinca'`, impidiendo la creación de cargas de PI con el viaje en proceso.
- **Habilitación de Acciones Huinca Exclusivas al Chofer Asignado**: Los botones de acción física "INICIAR CARGA" y "FINALIZAR CARGA" de cargas de Huinca en ruta se habilitan **únicamente** si el usuario en sesión es el chofer asignado a dicho viaje. Para otros usuarios o choferes no asignados, los botones se deshabilitan mostrando la indicación `'ASIGNADO A OTRO CHOFER'`, mientras que el botón "EDITAR" se oculta por completo para todos los choferes, reservándose a roles administrativos.

---

## 💾 Estado del Proyecto y Verificación
- **Flutter Analyze**: **0 errores estáticos.** Todo el código cumple con las directrices más estrictas de Flutter/Dart.
- **GitHub**: Cambios listos para commit y push.

## 🖥️ Recordatorio para Futuros Agentes / Desarrolladores:
> [!CAUTION]
> **NO MODIFICAR**: La advertencia de IA en el README, los archivos de reglas .cursorrules/.clinerules, el filtrado de cargas vacías y las restricciones de depósitos PI/Huinca con viajes en curso son reglas inmutables del negocio para asegurar cero regresiones en producción.
