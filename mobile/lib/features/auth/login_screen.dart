import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/slug.dart';
import '../billing/pricing_screen.dart';
import 'auth_errors.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Prellena empresa y correo de la última vez, para que no haya que reteclearlos.
    _prefill();
  }

  Future<void> _prefill() async {
    final store = ref.read(secureStoreProvider);
    final company = await store.lastCompany;
    final email = await store.lastEmail;
    if (!mounted) return;
    setState(() {
      if (company != null && _company.text.isEmpty) _company.text = company;
      if (email != null && _email.text.isEmpty) _email.text = email;
    });
  }

  @override
  void dispose() {
    _company.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final company = _company.text.trim();
    final email = _email.text.trim().toLowerCase();
    final password = _password.text.trim(); // mismo recorte que en el registro
    if (company.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Llena empresa, correo y contraseña.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final store = ref.read(secureStoreProvider);
    try {
      // El usuario escribe el NOMBRE de su empresa; la app lo traduce al
      // identificador interno igual que en el registro (ver slugify).
      await ref.read(authControllerProvider.notifier).login(
            companySlug: slugify(company),
            email: email,
            password: password,
          );
      await store.saveLastLogin(company, email);
      // Esta pantalla se abre con Navigator.push (desde la entrada rápida o el registro),
      // así que no se cierra sola cuando el AuthGate cambia a la app por debajo: hay que
      // quitarla para que quede a la vista el inventario.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        setState(() => _error = authErrorMessage(error, isRegister: false));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agua Segura')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text(
              'Agua Segura',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C74D9),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Protegemos tu hogar desde lo más alto',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF011829),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _company,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Tu negocio',
                hintText: 'El nombre de tu negocio',
              ),
            ),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            TextField(
              controller: _password,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  tooltip: _showPassword ? 'Ocultar' : 'Ver contraseña',
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
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Entrando…' : 'Entrar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
              child: const Text('¿No tienes cuenta? Crear cuenta'),
            ),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ResetPasswordScreen(
                            initialCompany: _company.text.trim(),
                            initialEmail: _email.text.trim(),
                          ),
                        ),
                      ),
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Prueba gratis · 1 semana',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF15803D),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PricingScreen()),
              ),
              icon: const Icon(Icons.sell_outlined),
              label: const Text('Ver planes y precios'),
            ),
          ],
        ),
      ),
    );
  }
}
