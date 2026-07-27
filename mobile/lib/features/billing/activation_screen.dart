import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'billing_api.dart';

/// Pantalla para que el cliente active su plan ingresando su clave de activación.
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _ok;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _activar() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _error = 'Escribe tu clave de activación.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _ok = null;
    });
    try {
      final status = await ref.read(billingApiProvider).redeem(code);
      if (mounted) {
        setState(() => _ok = '¡Plan activado! Ahora tienes ${status.businessesAllowed} '
            'negocio(s). ¡Gracias!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'No se pudo activar. Revisa que la clave sea correcta y no se haya usado.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activar mi plan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.vpn_key, size: 56, color: Color(0xFF2F6DF6)),
            const SizedBox(height: 12),
            const Text(
              'Ingresa tu clave de activación',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Es la clave que te compartieron al pagar tu plan (ej. AGORA-XXXX-XXXX).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              decoration: const InputDecoration(
                labelText: 'Clave',
                hintText: 'AGORA-XXXX-XXXX',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
            ],
            if (_ok != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_ok!,
                    style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _activar,
              child: Text(_loading ? 'Activando…' : 'Activar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formatea el texto a MAYÚSCULAS mientras se escribe (para las claves).
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
