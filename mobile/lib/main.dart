import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'features/auth/quick_login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/home/home_screen.dart';
import 'features/splash/splash_screen.dart';

void main() {
  runApp(const ProviderScope(child: AguaSeguraApp()));
}

class AguaSeguraApp extends StatelessWidget {
  const AguaSeguraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agua Segura',
      // El azul de la marca, el mismo del logo.
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1C74D9), useMaterial3: true),
      home: const _RootGate(),
    );
  }
}

/// Muestra la pantalla de bienvenida (splash) un instante al abrir y luego cede el
/// paso al AuthGate, que decide entre entrar, crear empresa o la app.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash ? const SplashScreen() : const _AuthGate();
  }
}

/// Decide qué pantalla mostrar al abrir la app:
/// - Con sesión (real o demo): la app (Home).
/// - Sin sesión y con una cuenta ya guardada en el equipo: "Entrar" (verde),
///   solo pide la contraseña.
/// - Sin sesión y sin cuenta guardada (primera vez): "Crear empresa" (naranja).
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  static const _loadingScreen =
      Scaffold(body: Center(child: CircularProgressIndicator()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return auth.when(
      loading: () => _loadingScreen,
      error: (_, __) => _firstScreen(ref),
      data: (session) =>
          session == SessionKind.none ? _firstScreen(ref) : const HomeScreen(),
    );
  }

  /// Elige entre "Entrar" (cuenta guardada) y "Crear empresa" (primera vez).
  Widget _firstScreen(WidgetRef ref) {
    final saved = ref.watch(savedAccountProvider);
    return saved.when(
      loading: () => _loadingScreen,
      error: (_, __) => const RegisterScreen(),
      data: (account) => account == null
          ? const RegisterScreen()
          : QuickLoginScreen(company: account.$1, email: account.$2),
    );
  }
}
