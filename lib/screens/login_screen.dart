import 'package:flutter/material.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/data/repositories/auth_repository.dart';
import 'package:delivery_app_v2/widgets/login_pattern.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool isLogin = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dniController = TextEditingController();
  final _direccionController = TextEditingController();
  final _mapsUrlController = TextEditingController();
  final _descripcionCasaController = TextEditingController();
  final _whatsappController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nombreController.dispose();
    _confirmPasswordController.dispose();
    _dniController.dispose();
    _direccionController.dispose();
    _mapsUrlController.dispose();
    _descripcionCasaController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    // En debug: permitir cualquier dominio para testing rápido.
    // En prod: SOLO @gmail.com.
    if (!kDebugMode && !AuthRepository.esDominioGmail(_emailController.text)) {
      _mostrarError('dominio desconocido');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .iniciarSesion(
            _emailController.text.trim(),
            _passwordController.text,
          );
      // El router redirige según el rol real (cliente -> /home, admin -> /admin).
      if (!mounted) return;
      // Volver al contexto que pidió el login (home, carrito, sorteo...).
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _mostrarError(_mensajeError(e));
    } catch (e) {
      if (!mounted) return;
      // En debug: loguear el error real para diagnosticar (App Check, red, etc.)
      // En release: el usuario solo ve el mensaje genérico (sin detalles internos).
      assert(() {
        debugPrint('[Login] Error no-FirebaseAuth: $e');
        return true;
      }());
      _mostrarError('Ocurrió un error. Intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    // En debug: permitir cualquier dominio para testing rápido.
    // En prod: SOLO @gmail.com.
    if (!kDebugMode && !AuthRepository.esDominioGmail(_emailController.text)) {
      _mostrarError('dominio desconocido');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .registrar(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            nombre: _nombreController.text.trim(),
            telefono: _whatsappController.text.trim(),
            direccion: _direccionController.text.trim(),
            mapsUrl: _mapsUrlController.text.trim(),
            descripcionCasa: _descripcionCasaController.text.trim(),
          );
      if (!mounted) return;
      // Volver al contexto que pidió el registro (home, carrito, sorteo...).
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _mostrarError(_mensajeError(e));
    } catch (e) {
      if (!mounted) return;
      _mostrarError('No se pudo crear la cuenta. Intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFFF4757)),
    );
  }

  String _mensajeError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        // GENÉRICO a propósito: no revelar si el email existe (anti-enumeration).
        return 'Email o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ese email ya está registrado.';
      case 'invalid-email':
        return 'El email no es válido.';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres).';
      default:
        // No filtrar detalles internos de Firebase al usuario.
        return 'Ocurrió un error. Intentá de nuevo.';
    }
  }

  static const String _telefono = '+5492494690672';

  void _copiarNumero() {
    Clipboard.setData(const ClipboardData(text: _telefono));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '📋 Número copiado',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Stack(
            children: [
              // Patrón decorativo vectorial de fondo (doodles de delivery).
              Positioned.fill(
                child: CustomPaint(
                  painter: LoginPatternPainter(
                    strokeColor: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Column(
                children: [
                  // Fila superior: flecha de volver alineada a la izquierda.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        // Volver atrás sin iniciar sesión.
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/home');
                              }
                            },
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            tooltip: 'Volver',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Header compacto: scooter + título.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '🛵',
                            style: TextStyle(fontSize: 30),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLogin ? 'Bienvenido' : 'Crear cuenta',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLogin
                              ? 'Inicia sesión en tu cuenta'
                              : 'Completá tus datos',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Formulario en tarjeta blanca "flotante".
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, -6),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              ..._buildFormFields(),
                              const SizedBox(height: 18),
                              Divider(
                                color: const Color(0xFFE4E4EC),
                                height: 1,
                              ),
                              const SizedBox(height: 14),
                              // Ayuda por WhatsApp (antes en el footer).
                              GestureDetector(
                                onTap: _copiarNumero,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        '💬',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '¿Necesitás ayuda? Escribinos por WhatsApp',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.green[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    if (isLogin) {
      return [
        _buildInputField(
          key: const Key('emailField'),
          label: 'Email',
          placeholder: 'juan@email.com',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresá tu email';
            if (!v.contains('@')) return 'Email inválido';
            if (!AuthRepository.esDominioGmail(v)) return 'dominio desconocido';
            return null;
          },
        ),
        const SizedBox(height: 15),
        _buildInputField(
          key: const Key('passwordField'),
          label: 'Contraseña',
          placeholder: '••••••••',
          controller: _passwordController,
          obscure: true,
          validator: (v) {
            if (v == null || v.length < 6) return 'Mínimo 6 caracteres';
            return null;
          },
        ),
        const SizedBox(height: 10),
        // Recuperar contraseña (envía email de reset de Firebase Auth).
        TextButton(
          onPressed: _isLoading
              ? null
              : () async {
                  final email = _emailController.text.trim();
                  if (email.isEmpty || !email.contains('@')) {
                    _mostrarError('Ingresá tu email arriba y volvé a tocar.');
                    return;
                  }
                  try {
                    await ref
                        .read(authRepositoryProvider)
                        .recuperarContrasena(email);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Si $email está registrado, te enviamos un email para recuperar la contraseña.',
                        ),
                        backgroundColor: const Color(0xFF2E9E5B),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (_) {
                    if (!mounted) return;
                    _mostrarError(
                      'No se pudo enviar el email. Intentá de nuevo.',
                    );
                  }
                },
          child: const Text(
            '¿Olvidaste tu contraseña?',
            // CORREGIDO: antes era Colors.white70 (invisible sobre fondo blanco)
            style: TextStyle(fontSize: 13, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _onLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Iniciar sesión',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        // ── Separador con texto ──
        Row(
          children: [
            Expanded(child: Divider(color: const Color(0xFFE4E4EC))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '¿No tenés cuenta?',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: const Color(0xFFE4E4EC))),
          ],
        ),
        const SizedBox(height: 14),
        // ── Botón destacado \"Crear cuenta\" ──
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() => isLogin = false);
                    _formKey.currentState?.reset();
                  },
            icon: const Icon(Icons.person_add_rounded, size: 20),
            label: const Text(
              'Crear cuenta',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary, width: 1.8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ];
    } else {
      return [
        _buildInputField(
          label: 'Nombre completo',
          placeholder: 'Juan Pérez',
          controller: _nombreController,
          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 15),
        _buildInputField(
          label: 'Email',
          placeholder: 'juan@email.com',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Requerido';
            if (!v.contains('@')) return 'Email inválido';
            return null;
          },
        ),
        const SizedBox(height: 15),
        _buildInputField(
          label: 'Número de DNI',
          placeholder: '12.345.678',
          controller: _dniController,
          keyboardType: TextInputType.number,
          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 15),
        _buildInputField(
          label: 'Dirección',
          placeholder: 'Calle 123, Ciudad',
          controller: _direccionController,
          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 15),
        _buildInputField(
          label: 'Link de Google Maps (opcional)',
          placeholder: 'https://maps.app.goo.gl/...',
          controller: _mapsUrlController,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 15),
        _buildInputField(
          label: '¿Cómo es tu casa? (pista para el delivery)',
          placeholder: 'Ej: portón negro, 2º piso, timbre 5, portón verde...',
          controller: _descripcionCasaController,
          maxLines: 2,
          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 15),
        _buildInputField(
          label: 'Número de WhatsApp',
          placeholder: '+54 9 11 1234-5678',
          controller: _whatsappController,
          keyboardType: TextInputType.phone,
          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildInputField(
                label: 'Contraseña',
                placeholder: '••••••••',
                controller: _passwordController,
                obscure: true,
                validator: (v) {
                  if (v == null || v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildInputField(
                label: 'Confirmar',
                placeholder: '••••••••',
                controller: _confirmPasswordController,
                obscure: true,
                validator: (v) {
                  if (v != _passwordController.text) return 'No coinciden';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _onRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Registrarse',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        // ── Volver al login ──
        TextButton.icon(
          onPressed: () {
            setState(() => isLogin = true);
            _formKey.currentState?.reset();
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text(
            '¿Ya tenés cuenta? Iniciar sesión',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          // CORREGIDO: antes era Colors.white (invisible sobre fondo blanco)
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ];
    }
  }

  Widget _buildInputField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    Key? key,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1F1F28),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: key,
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: obscure ? 1 : maxLines,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.95),
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFF999999)),
            errorStyle: const TextStyle(color: Color(0xFFE5484D), fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
