import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class LoggedWidget extends StatefulWidget {
  const LoggedWidget({super.key});
  
  static String routeName = 'Logged';
  static String routePath = '/logged';

  @override
  State<LoggedWidget> createState() => _LoggedWidgetState();
}

class _LoggedWidgetState extends State<LoggedWidget> {
  @override
  void initState() {
    super.initState();
    _checkRoleAndRedirect();
  }

  Future<void> _checkRoleAndRedirect() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) context.go('/welcome');
      return;
    }
    
    final uid = user.id;
    final client = Supabase.instance.client;

    try {
      final gerente = await client.from('v_profiles_gerente').select().eq('auth_user_id', uid).maybeSingle();
      if (gerente != null) {
        if (mounted) context.go('/gerenteHome');
        return;
      }

      final compras = await client.from('v_profiles_compras').select().eq('auth_user_id', uid).maybeSingle();
      if (compras != null) {
        if (mounted) context.go('/comprasHome');
        return;
      }

      final deposito = await client.from('v_profiles_deposito').select().eq('auth_user_id', uid).maybeSingle();
      if (deposito != null) {
        if (mounted) context.go('/depositoHome');
        return;
      }

      final chofer = await client.from('v_profiles_chofer').select().eq('auth_user_id', uid).maybeSingle();
      if (chofer != null) {
        if (mounted) context.go('/choferHome');
        return;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario sin rol asignado')),
        );
        context.go('/welcome');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error validando rol: $e')),
        );
        context.go('/welcome');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
