import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/slug.dart';
import 'auth_errors.dart';
import 'login_screen.dart';

/// Registro de una empresa nueva + su usuario dueño. El usuario solo escribe el
/// nombre del negocio, su correo y una contraseña; el identificador interno se
/// genera solo a partir del nombre (ver [slugify]).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _companyName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _companyName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _companyName.text.trim();
    final email = _email.text.trim().toLowerCase();
    // Se recorta la contraseña (igual que al entrar) para que un espacio invisible que
    // agregue el teclado no cause un "no coincide" al iniciar sesión después.
    final password = _password.text.trim();
    final companySlug = slugify(name);

    // Validación amigable antes de llamar al servidor.
    if (name.length < 2 || companySlug.length < 2) {
      setState(() => _error = 'Escribe el nombre de tu empresa (con letras).');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Escribe un correo válido.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'La contraseña debe tener al menos 8 caracteres.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final store = ref.read(secureStoreProvider);
    try {
      await ref.read(authControllerProvider.notifier).register(
            companyName: name,
            companySlug: companySlug,
            email: email,
            password: password,
          );
      // Éxito: la sesión ya es real. Guardamos los datos para el próximo ingreso
      // (pantalla verde "Entrar") y el AuthGate mostrará la app.
      await store.saveLastLogin(name, email);
      ref.invalidate(savedAccountProvider);
      // Si esta pantalla se abrió empujada (desde "Entrar"), no se cierra sola cuando el
      // AuthGate cambia a la app por debajo; se quita para dejar a la vista el inventario.
      // Si es la pantalla inicial (raíz), popUntil no hace nada: seguro en ambos casos.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e, isRegister: true));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recuadro naranja superior (primera vez que se abre la app).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Crear empresa',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Registra tu empresa',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Con estos datos entrarás después.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _companyName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre de la empresa',
                hintText: 'Ej: Modelorama Toño',
              ),
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
              controller: _password,
              obscureText: !_showPassword,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                helperText: 'Mínimo 8 caracteres. Toca el ojo para verla y anótala.',
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
                child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Creando…' : 'Crear cuenta'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                      ),
              child: const Text('¿Ya tienes empresa? Entrar'),
            ),
            const SizedBox(height: 4),
            const Text(
              'La primera vez puede tardar hasta ~1 minuto mientras el servidor despierta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
