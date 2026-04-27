import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'pages/gerentehome.dart';
import 'pages/necesidades_page.dart';
import 'pages/planificar_viaje.dart';
import 'pages/remito_page.dart';
import 'pages/viaje_detalle.dart';
import 'pages/pesajesitem.dart';
import 'pages/login.dart';
import 'pages/welcomepage.dart';
import 'pages/logged.dart';
import 'pages/paradadetalle.dart';
import 'pages/homepage.dart';
import 'pages/rutas_page.dart';
import 'pages/viajes_page.dart';

import 'index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('Main: Inicializando Supabase...');
    // Inicializar Supabase en todas las plataformas
    await Supabase.initialize(
      url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
    );
    print('Main: Supabase inicializado correctamente.');
  } catch (e) {
    print('Main: Error crítico al inicializar Supabase: $e');
    // Continuamos para que la app no quede en blanco, pero las llamadas fallarán con error controlado
  }

  runApp(const MyApp());
}

final _router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/',
      name: 'Root',
      builder: (context, state) => const WelcomePageWidget(),
    ),
    GoRoute(
      path: '/WelcomePage',
      name: 'WelcomePage',
      builder: (context, state) => const WelcomePageWidget(),
    ),
    GoRoute(
      path: '/login',
      name: 'Login',
      builder: (context, state) => const LoginWidget(),
    ),
    GoRoute(
      path: '/choferHome',
      name: 'ChoferHome',
      builder: (context, state) => const ChoferHomeWidget(),
    ),
    GoRoute(
      path: '/comprasHome',
      name: 'ComprasHome',
      builder: (context, state) => const ComprasHomeWidget(),
    ),
    GoRoute(
      path: '/depositoHome',
      name: 'DepositoHome',
      builder: (context, state) => const DepositoHomeWidget(),
    ),
    GoRoute(
      path: '/gerenteHome',
      name: 'GerenteHome',
      builder: (context, state) => const GerenteHomeWidget(),
    ),
    GoRoute(
      path: '/necesidades',
      name: 'Necesidades',
      builder: (context, state) => const NecesidadesPageWidget(),
    ),
    GoRoute(
      path: '/home',
      name: 'Home',
      builder: (context, state) => const HomePageWidget(),
    ),
    GoRoute(
      path: '/rutas',
      name: 'Rutas',
      builder: (context, state) => const RutasPageWidget(),
    ),
    GoRoute(
      path: '/viajes',
      name: 'Viajes',
      builder: (context, state) => const ViajesPageWidget(),
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
      path: '/logged',
      name: 'Logged',
      builder: (context, state) => const LoggedWidget(),
    ),
    GoRoute(
      path: '/paradaDetalle',
      name: 'ParadaDetalle',
      builder: (context, state) {
        final paradaId = state.uri.queryParameters['paradaId'] ?? '';
        return ParadaDetalleWidget(paradaId: paradaId);
      },
    ),
    GoRoute(
      path: '/pesajesItem',
      name: 'PesajesItem',
      builder: (context, state) {
        final paradaItemId = state.uri.queryParameters['paradaItemId'];
        final paradaId = state.uri.queryParameters['paradaId'];
        return PesajesItemWidget(
            paradaItemId: paradaItemId, paradaId: paradaId);
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
      path: '/planificarViaje',
      name: 'PlanificarViaje',
      builder: (context, state) => const PlanificarViajeWidget(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Geo Logistica',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF08201A)),
        useMaterial3: true,
      ),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
