import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Configura POR PRIMERA VEZ el secreto de administrador desde la app (se guarda
/// cifrado en el servidor). Así el dueño NO depende de variables de entorno.
/// Si el servidor ya tiene uno, avisa y no deja crear otro.
class AdminSetupScreen extends ConsumerStatefulWidget {
  const AdminSetupScreen({super.key});

  @override
  ConsumerState<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends ConsumerState<AdminSetupScreen> {
  final _secret = TextEditingController();
  bool _showSecret = false;
  bool _loading = false;
  bool _checking = true;
  bool _configured = false;
  String? _error;
  String? _ok;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _secret.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final configured = await ref.read(authRepositoryProvider).adminConfigured();
      if (mounted) setState(() => _configured = configured);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pude consultar el servidor. Puede estar '
            'despertando: espera ~1 minuto y vuelve a abrir esta pantalla.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _guardar() async {
    final secret = _secret.text.trim();
    if (secret.length < 6) {
      setState(() => _error = 'El secreto debe tener al menos 6 caracteres.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _ok = null;
    });
    try {
      await ref.read(authRepositoryProvider).bootstrapAdmin(secret);
      if (mounted) {
        setState(() {
          _configured = true;
          _ok = '¡Listo! Tu secreto de administrador quedó configurado. '
              'Anótalo bien: lo usarás para restablecer contraseñas y generar claves.';
        });
      }
    } catch (e) {
      if (mounted) {
        final code = e is DioException ? e.response?.statusCode : null;
        setState(() => _error = code == 409
            ? 'Este servidor YA tiene un secreto configurado. No se puede cambiar aquí.'
            : 'No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secreto de administrador')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.admin_panel_settings, size: 52, color: Color(0xFF2F6DF6)),
            const SizedBox(height: 8),
            const Text(
              'Configura tu secreto de administrador',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Es una contraseña maestra tuya (del dueño). Sirve para restablecer '
              'contraseñas de clientes y generar claves de activación. Se guarda '
              'segura en el servidor. Hazlo una sola vez.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (_checking)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_configured && _ok == null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF15803D)),
                ),
                child: const Text(
                  'Este servidor YA tiene un secreto de administrador configurado. '
                  'Úsalo para restablecer contraseñas. Si lo olvidaste, contáctame.',
                  style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                ),
              ),
            ] else ...[
              TextField(
                controller: _secret,
                obscureText: !_showSecret,
                decoration: InputDecoration(
                  labelText: 'Nuevo secreto de administrador',
                  helperText: 'Mínimo 6 caracteres. Anótalo: lo pedirá para restablecer.',
                  suffixIcon: IconButton(
                    icon: Icon(_showSecret ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showSecret = !_showSecret),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _guardar,
                child: Text(_loading ? 'Guardando…' : 'Guardar secreto'),
              ),
            ],
            if (_ok != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_ok!,
                    style: const TextStyle(
                        color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check),
                label: const Text('Continuar'),
              ),
            ],
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
          ],
        ),
      ),
    );
  }
}
