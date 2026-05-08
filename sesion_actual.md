# Blueprint Maestro de Sesión: GeoLogística
**Fecha de actualización:** 08 de Mayo de 2026 (17:00hs)

## 1. Contexto del Proyecto
GeoLogística es una plataforma integral para la gestión logística de la industria apícola, diseñada bajo el sistema estético "Stitch Premium" (Verde Bosque, Dorado Miel, Crema). La aplicación gestiona desde la solicitud del productor hasta la entrega final y el pesaje, integrando Supabase como motor de datos.

## 2. Arquitectura Técnica
*   **Framework:** Flutter (Mobile/Desktop).
*   **Backend:** Supabase (Auth, DB, Storage).
*   **Navegación:** GoRouter (Rutas centralizadas en `main.dart`).
*   **Estado:** State Management local + SharedPreferences para persistencia de roles y sesión.
*   **Diseño:** `DesignTokens` (localizado en `lib/backend/design_tokens.dart`) define la paleta oficial (#08201A, #C68E17, #FBFBFB).

## 3. Modelo de Datos y Lógica de Negocio (Core)
### Tablas Críticas en Supabase:
*   **`apicultores`**: Maestro de productores. El campo `apicultor_codigo` (ej: A01887) es el identificador humano, mientras que `id` es el UUID/Serial.
*   **`solicitudes`**: Pedidos de "Recolección" o "Distribución". Se vinculan mediante `apicultor_id` (que puede ser el UUID o el código humano en algunos casos históricos).
*   **`viajes`**: Contenedor principal de rutas. Estados: `Planificado`, `En Proceso`, `Terminado`.
*   **`paradas`**: Nodos de un viaje. Vinculados a una `solicitud`.
*   **`parada_items`**: Detalle de productos (Tambores, Alzas, Insumos) por parada.
*   **`remitos`**: Documentos digitales finales vinculados a una parada/viaje.

## 4. Avances Consolidados (Día 1 hasta Hoy)
### Módulos Finalizados:
*   **Autenticación**: Login robusto con redirección por roles (Chofer, Gerente, CEO, Compras).
*   **Directorio de Apicultores**: Búsqueda por nombre/localidad y ficha técnica detallada.
*   **Planificador de Rutas**: Sistema de creación de viajes con selección de vehículo, chofer y paradas múltiples.
*   **Control de Pesajes**: Interfaz premium para el registro de kilos brutos, tara y neto.
*   **Gestión de Gastos**: Registro de combustible, peajes y viáticos con soporte para imágenes (en proceso).
*   **Remitos Digitales (NUEVO)**: Interfaz de alta fidelidad con filtros por tipo de operación y búsqueda integrada.

## 5. Cambios Específicos de Hoy (08/05/2026)
*   **Estabilización de Datos**: Se restauró la búsqueda estricta en `apicultor_detalle.dart`. Ahora el sistema busca coincidencias por ID único y Código alternativo, garantizando que las 6 solicitudes cargadas para el usuario de prueba (Walter) sean visibles.
*   **Interfaz de Remitos**: Se eliminaron elementos heredados de "ApiaryLogistics". La página ahora muestra "Remitos PDF" con una barra de navegación funcional (Flota, Apicultores, Rutas, Remitos).
*   **Branding GeoLogística**: Eliminación de overlays de debug rojos y limpieza de la AppBar para un look premium minimalista.

## 6. Estado para la Próxima IA (Handoff)
*   **Repositorio**: Sincronizado en GitHub.
*   **Punto de Control**: La app compila correctamente. El flujo de "Operaciones Pendientes" en la ficha del apicultor ya consume datos reales de Supabase.
*   **Pendientes Próxima Sesión**:
    1. Conectar el botón "VER PDF" en la lista de remitos a la lógica de generación de documentos.
    2. Validar el flujo de carga de imágenes en el módulo de Gastos.
    3. Pruebas de estrés en la sincronización Google Sheets -> Supabase.

---
*Este documento es la única fuente de verdad para la continuidad del desarrollo. GeoLogística v1.0.5 - "Ready for Field Testing".*
