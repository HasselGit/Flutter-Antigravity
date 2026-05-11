import '../backend/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/supabase_service.dart';
import 'dart:ui';
import 'dart:math';

class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, ingresa email y contraseña')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService().login(email, password);
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) {
        String msg = error.toString().replaceAll('Exception:', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de acceso: $msg'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      body: Stack(
        children: [
          Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: LoginHoneycombPainter(color: DesignTokens.primary.withOpacity(0.03))))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: DesignTokens.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: ClipOval(child: Image.asset('assets/images/logo_Geologistica_Verde.png', cacheWidth: 240, fit: BoxFit.contain)),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 12))],
                      ),
                      child: Column(
                        children: [
                          const Text('¡Bienvenido!', style: TextStyle(fontFamily: 'Manrope', fontSize: 24, fontWeight: FontWeight.w800, color: DesignTokens.primary)),
                          const SizedBox(height: 8),
                          const Text('Inicia sesión para continuar', style: TextStyle(fontFamily: 'Inter', color: DesignTokens.onSurfaceVariant)),
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
                      onPressed: () => context.go('/'),
                      child: const Text('VOLVER', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, color: DesignTokens.primary, letterSpacing: 1)),
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: DesignTokens.primary.withOpacity(0.5)),
        filled: true,
        fillColor: DesignTokens.surfaceLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        labelStyle: TextStyle(color: DesignTokens.primary.withOpacity(0.5)),
      ),
    );
  }
}

class LoginHoneycombPainter extends CustomPainter {
  final Color color;
  LoginHoneycombPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.0;
    const radius = 40.0;
    final hexWidth = radius * sqrt(3);
    final hexHeight = radius * 2;
    for (double y = -radius; y < size.height + radius; y += hexHeight * 0.75) {
      bool offset = ((y / (hexHeight * 0.75)).round() % 2 == 0);
      for (double x = -hexWidth; x < size.width + hexWidth; x += hexWidth) {
        double cx = x + (offset ? hexWidth / 2 : 0);
        _drawHexagon(canvas, Offset(cx, y), radius, paint);
      }
    }
  }
  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      double angle = (pi / 3) * i - (pi / 2);
      double x = center.dx + radius * cos(angle);
      double y = center.dy + radius * sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
