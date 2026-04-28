import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'index.dart';

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
      builder: (context, state) => const PlanificarViajeWidget(),
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
      path: '/paradaDetalle',
      name: 'paradaDetalle',
      builder: (context, state) {
        final paradaId = state.uri.queryParameters['paradaId'] ?? '';
        return ParadaDetalleWidget(paradaId: paradaId);
      },
    ),
    GoRoute(
      path: '/pesajesitem',
      name: 'PesajesItem',
      builder: (context, state) {
        final paradaId = state.uri.queryParameters['paradaId'] ?? '';
        return PesajesItemWidget(paradaId: paradaId);
      },
    ),
    GoRoute(
      path: '/remito',
      name: 'RemitoPage',
      builder: (context, state) {
        final paradaId = state.uri.queryParameters['paradaId'] ?? '';
        return RemitoPageWidget(paradaId: paradaId);
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
  ],
);
