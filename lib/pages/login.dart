import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase_service.dart';
import 'dart:ui';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  static String routeName = 'Login';
  static String routePath = '/login';

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _loggedUserData;

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa email y contraseña')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      print('Login: Intentando ingresar con $email');
      await SupabaseService().login(email, password);
      
      if (mounted) {
        context.go('/home');
      }
    } catch (error) {
      print('Login: Error en el proceso: $error');
      if (mounted) {
        String msg = error.toString();
        if (msg.contains('Exception:')) msg = msg.split('Exception:').last.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de acceso: $msg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: Stack(
        children: [
          // Honeycomb Background
          Positioned.fill(
            child: CustomPaint(
              painter: LoginHoneycombPainter(
                color: theme.primary.withOpacity(0.03),
                strokeWidth: 1.5,
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo with Premium Container
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.primary.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo_Geologistica_Verde.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.primary.withOpacity(0.05),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primary.withOpacity(0.04),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Acceso Seguro',
                            style: theme.displaySmall.override(
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.bold,
                              color: theme.primary,
                              fontSize: 26,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ingresa tus credenciales técnicas',
                            style: theme.bodyMedium.override(
                              fontFamily: 'Inter',
                              color: theme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildTextField(
                            controller: _emailController,
                            label: 'Correo Electrónico',
                            icon: Icons.alternate_email_rounded,
                            theme: theme,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Contraseña',
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                            theme: theme,
                          ),
                          const SizedBox(height: 32),
                          // Premium Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: theme.secondary,
                                    width: 1.5,
                                  ),
                                ),
                              ).copyWith(
                                overlayColor: MaterialStateProperty.all(theme.secondary.withOpacity(0.1)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'INGRESAR AL SISTEMA',
                                      style: theme.labelSmall.override(
                                        fontFamily: 'Work Sans',
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: Text(
                        'VOLVER',
                        style: theme.labelSmall.override(
                          fontFamily: 'Work Sans',
                          fontWeight: FontWeight.bold,
                          color: theme.secondary,
                          letterSpacing: 1,
                        ),
                      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    required FlutterFlowTheme theme,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: theme.bodyMedium.override(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        color: theme.primary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: theme.labelSmall.override(
          fontFamily: 'Work Sans',
          color: theme.secondaryText.withOpacity(0.6),
        ),
        prefixIcon: Icon(icon, color: theme.secondary, size: 20),
        filled: true,
        fillColor: theme.primaryBackground,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.primary.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.secondary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class LoginHoneycombPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  LoginHoneycombPainter({required this.color, this.strokeWidth = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const double r = 30.0; // radio de cada celda
    final double h = r * sqrt(3); // altura entre filas

    for (double y = 0; y < size.height + h; y += h) {
      double offsetX = (y / h).round() % 2 == 0 ? 0 : r * 1.5;
      for (double x = -r * 2; x < size.width + r * 2; x += r * 3) {
        _drawHexagon(canvas, x + offsetX, y, r, paint);
      }
    }
  }

  void _drawHexagon(Canvas canvas, double x, double y, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      double angle = i * pi / 3;
      double px = x + r * cos(angle);
      double py = y + r * sin(angle);
      if (i == 0) path.moveTo(px, py);
      else path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
