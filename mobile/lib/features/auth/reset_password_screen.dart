import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/slug.dart';
import 'admin_setup_screen.dart';

/// Restablecer la contraseña de una cuenta. Pensada para que el DUEÑO (con su
/// secreto de administrador) recupere el acceso de un cliente que olvidó su clave.
/// Tras restablecer, entra automáticamente con la nueva contraseña.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialCompany = '', this.initialEmail = ''});
  final String initialCompany;
  final String initialEmail;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final _company = TextEditingController(text: widget.initialCompany);
  late final _email = TextEditingController(text: widget.initialEmail);
  final _newPassword = TextEditingController();
  final _secret = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _company.dispose();
    _email.dispose();
    _newPassword.dispose();
    _secret.dispose();
    super.dispose();
  }

  String _mapError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 503) {
        return 'El servidor aún no tiene cargado el secreto (o sigue reiniciando '
            'tras guardarlo en Render). Espera 1-2 minutos y toca de nuevo '
            '"Restablecer y entrar".';
      }
      if (code == 403) {
        return 'El secreto NO coincide con el del servidor. Revísalo carácter por '
            'carácter (ojo con la letra O vs el número 0, y mayúsculas).';
      }
      if (code == 404) {
        return 'No existe una empresa con ese nombre y correo. Revísalos.';
      }
      if (code == 422) {
        return 'Revisa los datos: correo válido y contraseña de al menos 8 caracteres.';
      }
      if (code != null && code >= 500) {
        return 'El servidor tuvo un problema. Espera unos segundos y reintenta.';
      }
      return 'No pude conectar con el servidor. Puede estar despertando: '
          'espera ~1 minuto y reintenta.';
    }
    return 'No se pudo restablecer. Inténtalo de nuevo.';
  }

  Future<void> _submit() async {
    final company = _company.text.trim();
    final email = _email.text.trim().toLowerCase();
    final newPassword = _newPassword.text;
    if (company.isEmpty || email.isEmpty) {
      setState(() => _error = 'Escribe la empresa y el correo.');
      return;
    }
    if (newPassword.length < 8) {
      setState(() => _error = 'La nueva contraseña debe tener al menos 8 caracteres.');
      return;
    }
    if (_secret.text.trim().isEmpty) {
      setState(() => _error = 'Escribe tu secreto de administrador.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final companySlug = slugify(company);
      await ref.read(authRepositoryProvider).resetPassword(
            companySlug: companySlug,
            email: email,
            newPassword: newPassword,
            adminSecret: _secret.text.trim(),
          );
      // Restablecida: entramos con la nueva contraseña y guardamos la cuenta.
      await ref.read(authControllerProvider.notifier).login(
            companySlug: companySlug,
            email: email,
            password: newPassword,
          );
      await ref.read(secureStoreProvider).saveLastLogin(company, email);
      ref.invalidate(savedAccountProvider);
      // El AuthGate ya muestra la app POR DEBAJO, pero esta pantalla se abrió con
      // Navigator.push y no se cierra sola: hay que quitarla (y las que estén encima)
      // para que quede a la vista el inventario. Sin esto, el usuario queda logueado
      // pero mirando una pantalla de login/reset que ya no aplica.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = _mapError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_reset, size: 52, color: Color(0xFF2F6DF6)),
            const SizedBox(height: 8),
            const Text(
              'Ponle una nueva contraseña a tu cuenta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Necesitas tu secreto de administrador (el del servidor). Al terminar, '
              'entras directo con la nueva contraseña.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _company,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Empresa'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newPassword,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                helperText: 'Mínimo 8 caracteres. Toca el ojo para verla y anótala.',
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _secret,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Secreto de administrador',
                helperText: 'El valor de LICENSE_ADMIN_SECRET del servidor.',
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
                child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Restableciendo…' : 'Restablecer y entrar'),
            ),
            const Divider(height: 32),
            const Text(
              '¿Primera vez? Si el servidor aún no tiene secreto de administrador, '
              'créalo aquí (una sola vez):',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AdminSetupScreen()),
                      ),
              icon: const Icon(Icons.admin_panel_settings, size: 18),
              label: const Text('Configurar secreto por primera vez'),
            ),
          ],
        ),
      ),
    );
  }
}
