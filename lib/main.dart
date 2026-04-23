import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'pages/choferhome.dart';
import 'pages/comprashome.dart';
import 'pages/homepage.dart';
import 'pages/rutas_page.dart';
import 'pages/viajes_page.dart';

import 'index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase solo en plataformas no-web
  if (!kIsWeb) {
    await Supabase.initialize(
      url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
      anonKey: 'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
    );
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
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Geo Logistica',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A5D23)),
        useMaterial3: true,
      ),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
