import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/slug.dart';
import '../billing/pricing_screen.dart';
import 'auth_errors.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

/// Pantalla de entrada rápida (para cuando YA hay una cuenta guardada en el equipo):
/// muestra la empresa y solo pide la contraseña. Recuadro verde arriba.
class QuickLoginScreen extends ConsumerStatefulWidget {
  const QuickLoginScreen({super.key, required this.company, required this.email});
  final String company;
  final String email;

  @override
  ConsumerState<QuickLoginScreen> createState() => _QuickLoginScreenState();
}

class _QuickLoginScreenState extends ConsumerState<QuickLoginScreen> {
  final _password = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final password = _password.text.trim(); // mismo recorte que en el registro
    if (password.isEmpty) {
      setState(() => _error = 'Escribe tu contraseña.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(
            companySlug: slugify(widget.company),
            email: widget.email,
            password: password,
          );
      // Éxito: el AuthGate cambia a la app.
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e, isRegister: false));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Recuadro verde superior.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF15803D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Entrar',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 28),
              const Text('Agua Segura',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1C74D9))),
              const SizedBox(height: 16),
              Text('Negocio: ${widget.company}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text(widget.email, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              TextField(
                controller: _password,
                obscureText: !_showPassword,
                autofocus: true,
                onSubmitted: (_) => _entrar(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
                      const SizedBox(height: 8),
                      // Si no logra entrar, la vía segura para recuperar el acceso es
                      // ponerle una nueva contraseña (con el secreto de administrador).
                      FilledButton.icon(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ResetPasswordScreen(
                                      initialCompany: widget.company,
                                      initialEmail: widget.email,
                                    ),
                                  ),
                                ),
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Restablecer contraseña y entrar'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _entrar,
                  child: Text(_loading ? 'Entrando…' : 'Entrar'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ResetPasswordScreen(
                              initialCompany: widget.company,
                              initialEmail: widget.email,
                            ),
                          ),
                        ),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                        ),
                child: const Text('Entrar con otra empresa'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PricingScreen()),
                ),
                child: const Text('Ver planes y precios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
