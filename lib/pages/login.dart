import '../backend/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/supabase_service.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  // Controladores de texto limpios para producción
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus(); // Cerramos teclado antes de navegar
    
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, ingresa email y contraseña')));
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    try {
      await SupabaseService().login(email, password);
      
      if (mounted) {
        setState(() => _isLoading = false);
        // Garantizamos que la UI respire antes de navegar para evitar bloqueos en el emulador
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          context.go('/home');
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${error.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Manejo estándar de teclado
      backgroundColor: DesignTokens.surfaceLow,
      body: Stack(
        children: [
          // Fondo sólido simple sin paneles
          Positioned.fill(
            child: Container(color: DesignTokens.surfaceLow),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RepaintBoundary(
                      child: _LoginLogo(),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Text('¡Bienvenido!', style: DesignTokens.headlineStyle()),
                          const SizedBox(height: 8),
                          Text('Inicia sesión para continuar', style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant)),
                          const SizedBox(height: 32),
                          _buildTextField(controller: _emailController, label: 'Correo Electrónico', icon: Icons.alternate_email_rounded),
                          const SizedBox(height: 16),
                          _buildTextField(controller: _passwordController, label: 'Contraseña', icon: Icons.lock_outline_rounded, isPassword: true),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: DesignTokens.secondaryButtonStyle,
                              child: _isLoading 
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: DesignTokens.primary, strokeWidth: 2))
                                : const Text('INGRESAR AL SISTEMA'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text('VOLVER', style: DesignTokens.labelStyle(color: DesignTokens.primary)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.emailAddress,
      textInputAction: isPassword ? TextInputAction.done : TextInputAction.next,
      onSubmitted: (_) => isPassword ? _signIn() : FocusScope.of(context).nextFocus(),
      // USAMOS FUENTE DE SISTEMA PARA EVITAR BLOQUEOS DE GOOGLE FONTS EN EMULADOR
      style: const TextStyle(
        fontFamily: 'sans-serif', 
        fontSize: 16,
        color: DesignTokens.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: DesignTokens.primary.withOpacity(0.5)),
        filled: true,
        fillColor: DesignTokens.surfaceLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        labelStyle: TextStyle(color: DesignTokens.primary.withOpacity(0.5)),
        // Añadimos una sugerencia visual de email si no es password para ayudar al usuario
        hintText: !isPassword ? "ejemplo@correo.com" : null,
        hintStyle: TextStyle(color: DesignTokens.primary.withOpacity(0.2), fontSize: 14),
      ),
    );
  }
}

class _LoginLogo extends StatelessWidget {
  const _LoginLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: DesignTokens.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo_Geologistica_Verde.png',
          cacheWidth: 240,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
