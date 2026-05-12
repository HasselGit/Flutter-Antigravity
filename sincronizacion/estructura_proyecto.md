# 📂 Estructura del Proyecto: GeoLogística

Este documento describe la organización de carpetas y archivos del proyecto para facilitar la sincronización con otros sistemas de IA.

## 🏗 Arquitectura de Carpetas
- `lib/`: Directorio raíz del código Dart.
  - `backend/`: Lógica de datos, servicios de Supabase y estados globales.
    - `supabase/`: Configuraciones específicas de Supabase.
    - `supabase_service.dart`: **Corazón del sistema**. Maneja todas las queries y lógica de negocio.
    - `design_tokens.dart`: Sistema de diseño (colores, fuentes, estilos de botones).
    - `app_states.dart`: Manejo de estados de la aplicación (Pendiente, En Curso, Terminado).
  - `components/`: Widgets reutilizables en múltiples páginas.
  - `pages/`: Vistas completas de la aplicación (Screens).
    - `homepage.dart`: Dashboard principal para roles administrativos.
    - `choferhome.dart`: Vista optimizada para conductores.
    - `login.dart`: Interfaz de acceso.
    - `welcomepage.dart`: Pantalla de inicio con branding.
  - `flutter_flow/`: Archivos base del framework (exportación de FlutterFlow).
  - `main.dart`: Punto de entrada e inicialización de servicios.
  - `index.dart`: Índice de exportaciones globales.

## 💾 Tecnologías Principales
1.  **Frontend**: Flutter (3.22+) - UI Premium con sistema de diseño personalizado (Stitch).
2.  **Backend**: Supabase (PostgreSQL + Auth).
3.  **Navegación**: GoRouter (Manejo de rutas declarativas).
4.  **Localización**: Soporte completo para `es_AR` (Argentina).

## 📄 Archivos de Configuración Críticos
1.  `pubspec.yaml`: Dependencias y recursos (imágenes, fuentes).
2.  `android/gradle.properties`: Configuración de memoria y ruta del JDK.
3.  `android/app/build.gradle`: Versiones de compilación (SDK 34+, Java 17).
4.  `sesion_actual.md`: Diario de cambios y estado actual de desarrollo.
