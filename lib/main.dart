import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'pages/recolecciones_page.dart';
import 'pages/pesajes_page.dart';
import 'pages/distribuciones_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pages/vehiculo_detalle_page.dart';
import 'pages/productos_page.dart';
import 'pages/vehiculos_page.dart';
import 'pages/necesidades_page.dart';
import 'pages/rutas_page.dart';
import 'pages/viajes_page.dart';
import 'pages/viaje_detalle.dart';
import 'pages/ruta_detalle.dart';
import 'pages/paradadetalle.dart';
import 'pages/pesajesitem.dart';
import 'pages/remito_page.dart';
import 'pages/homepage.dart';
import 'pages/choferhome.dart';
import 'pages/gerentehome.dart';
import 'pages/welcomepage.dart';
import 'pages/login.dart';
import 'pages/logged.dart';
import 'pages/comprashome.dart';
import 'pages/depositohome.dart';
import 'pages/planificar_viaje.dart';
import 'pages/apicultores_page.dart';
import 'pages/gastos_page.dart';
import 'pages/remitos_lista_page.dart';
import 'pages/agregar_pesaje.dart';
import 'pages/cargas_page.dart';
import 'pages/carga_detalle.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print('Main: Inicializando Supabase...');
    await Supabase.initialize(
      url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
    );
    print('Main: Supabase OK');
    
    print('Main: Inicializando Locale...');
    await initializeDateFormatting('es_AR', null);
    print('Main: Locale OK');
  } catch (e) {
    print('Main: Error en inicialización: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GeoLogística',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'WelcomePage',
      builder: (context, state) => const WelcomePageWidget(),
    ),
    GoRoute(
      path: '/login',
      name: 'Login',
      builder: (context, state) => const LoginWidget(),
    ),
    GoRoute(
      path: '/logged',
      name: 'Logged',
      builder: (context, state) => const LoggedWidget(),
    ),
    GoRoute(
      path: '/home',
      name: 'HomePage',
      builder: (context, state) => const HomePageWidget(),
    ),
    GoRoute(
      path: '/choferHome',
      name: 'choferHome',
      builder: (context, state) => const ChoferHomeWidget(),
    ),
    GoRoute(
      path: '/gerenteHome',
      name: 'gerenteHome',
      builder: (context, state) => const GerenteHomeWidget(),
    ),
    GoRoute(
      path: '/comprasHome',
      name: 'comprasHome',
      builder: (context, state) => const ComprasHomeWidget(),
    ),
    GoRoute(
      path: '/depositoHome',
      name: 'depositoHome',
      builder: (context, state) => const DepositoHomeWidget(),
    ),
    GoRoute(
      path: '/necesidades',
      name: 'NecesidadesPage',
      builder: (context, state) => const NecesidadesPageWidget(),
    ),
    GoRoute(
      path: '/planificarViaje',
      name: 'PlanificarViaje',
      builder: (context, state) {
        final editId = state.uri.queryParameters['editId'];
        return PlanificarViajeWidget(editId: editId);
      },
    ),
    GoRoute(
      path: '/viajedetalle',
      name: 'ViajeDetalle',
      builder: (context, state) {
        final viajeId = state.uri.queryParameters['viajeId'] ?? '';
        return ViajeDetalleWidget(viajeId: viajeId);
      },
    ),
    GoRoute(
      path: '/rutadetalle',
      name: 'RutaDetalle',
      builder: (context, state) {
        final viajeId = state.uri.queryParameters['viajeId'] ?? '';
        return RutaDetalleWidget(viajeId: viajeId);
      },
    ),
    GoRoute(
      path: '/paradaDetalle',
      name: 'paradaDetalle',
      builder: (context, state) {
        final paradaId = state.uri.queryParameters['paradaId'] ?? '';
        return ParadaDetalleWidget(paradaId: paradaId);
      },
    ),
    GoRoute(
      path: '/pesajes',
      name: 'Pesajes',
      builder: (context, state) => const PesajesPageWidget(),
    ),
    GoRoute(
      path: '/pesajesItem',
      name: 'pesajesItem',
      builder: (context, state) {
        final paradaId = state.uri.queryParameters['paradaId'] ?? '';
        final paradaItemId = state.uri.queryParameters['paradaItemId'];
        return PesajesItemWidget(paradaId: paradaId, paradaItemId: paradaItemId);
      },
    ),
    GoRoute(
      path: '/remito',
      name: 'RemitoPage',
      builder: (context, state) {
        final params = state.uri.queryParameters;
        return RemitoPageWidget(
          paradaId: params['paradaId'] ?? '',
          receptorTipo: params['receptorTipo'],
          receptorNombre: params['receptorNombre'],
          receptorDni: params['receptorDni'],
        );
      },
    ),
    GoRoute(
      path: '/rutas',
      name: 'rutasPage',
      builder: (context, state) => const RutasPageWidget(),
    ),
    GoRoute(
      path: '/viajes',
      name: 'viajesPage',
      builder: (context, state) => const ViajesPageWidget(),
    ),
    GoRoute(
      path: '/recolecciones',
      name: 'recoleccionesPage',
      builder: (context, state) => const RecoleccionesPageWidget(),
    ),
    GoRoute(
      path: '/distribuciones',
      name: 'distribucionesPage',
      builder: (context, state) => const DistribucionesPageWidget(),
    ),
    GoRoute(
      path: '/vehiculos',
      name: 'VehiculosPage',
      builder: (context, state) => const VehiculosPageWidget(),
    ),
    GoRoute(
      path: '/vehiculoDetalle',
      name: 'VehiculoDetalle',
      builder: (context, state) {
        final vehiculoId = state.uri.queryParameters['id'];
        return VehiculoDetalleWidget(vehiculoId: vehiculoId);
      },
    ),
    GoRoute(
      path: '/productos',
      name: 'ProductosPage',
      builder: (context, state) => const ProductosPageWidget(),
    ),
    GoRoute(
      path: '/apicultores',
      name: 'ApicultoresPage',
      builder: (context, state) => const ApicultoresPageWidget(),
    ),
    GoRoute(
      path: '/gastos',
      name: 'GastosPage',
      builder: (context, state) => const GastosPageWidget(),
    ),
    GoRoute(
      path: '/remitosLista',
      name: 'RemitosListaPage',
      builder: (context, state) => const RemitosListaPageWidget(),
    ),
    GoRoute(
      path: '/agregarPesaje',
      name: 'AgregarPesaje',
      builder: (context, state) {
        // Acepta params por extra (desde context.push) o por queryParameters (URL directa)
        final extra = state.extra as Map<String, dynamic>?;
        final params = state.uri.queryParameters;
        return AgregarPesajeWidget(
          paradaId: extra?['paradaId']?.toString() ?? params['paradaId'] ?? '',
          viajeId: extra?['viajeId']?.toString() ?? params['viajeId'],
          viajeCode: extra?['viajeCode']?.toString() ?? params['viajeCode'] ?? 'V-S/N',
          apicultorNombre: extra?['apicultorNombre']?.toString() ?? params['apicultorNombre'] ?? 'S/D',
          localidad: extra?['localidad']?.toString() ?? params['localidad'] ?? 'S/D',
          apicultorId: extra?['apicultorId']?.toString() ?? params['apicultorId'],
        );
      },
    ),
    GoRoute(
      path: '/cargas',
      name: 'CargasPage',
      builder: (context, state) => const CargasPageWidget(),
    ),
    GoRoute(
      path: '/cargaDetalle',
      name: 'CargaDetalle',
      builder: (context, state) {
        final id = state.uri.queryParameters['id'];
        final isNew = state.uri.queryParameters['new'] == 'true';
        return CargaDetalleWidget(cargaId: id, isNew: isNew);
      },
    ),
  ],
);
