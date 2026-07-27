import 'package:flutter/material.dart';

/// Pantalla de bienvenida (splash) de Agua Segura: la insignia sobre el azul marino de
/// la marca, con el eslogan debajo. Se muestra un instante al abrir la app y luego cede
/// el paso al AuthGate.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// El azul marino del logo (#011829): hace resaltar la insignia.
  static const Color background = Color(0xFF011829);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/branding/logo.png',
              width: width * 0.72,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 22),
            const Text(
              'HOGAR PROTEGIDO, AGUA SEGURA',
              style: TextStyle(
                color: Color(0xFF5EB2FF),
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
