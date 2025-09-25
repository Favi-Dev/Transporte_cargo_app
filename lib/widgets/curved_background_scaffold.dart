// lib/widgets/curved_background_scaffold.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// REFACTORIZACIÓN CLAVE:
/// El widget ha sido mejorado para manejar correctamente tanto contenido estático
/// como contenido con scroll (SingleChildScrollView).
class CurvedBackground extends StatelessWidget {
  final Widget child;
  /// Factor de altura relativo al alto disponible del body (por defecto 0.2 = 20%).
  final double heightFactor;
  /// Altura fija opcional para la ola (tiene prioridad sobre heightFactor si se define).
  final double? fixedHeight;
  /// Si es true, aplica un padding inferior al contenido para evitar que quede
  /// demasiado pegado a la curva de la ola.
  final bool padBottomByWave;

  const CurvedBackground({
    Key? key,
    required this.child,
    this.heightFactor = 0.2,
    this.fixedHeight,
    this.padBottomByWave = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Usar LayoutBuilder asegura que tomamos el alto real del body (ya descontado AppBar/SafeArea)
    // evitando que la ola se vea descentrada, especialmente con contenido scrollable.
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final waveHeight = (fixedHeight != null)
            ? fixedHeight!.clamp(0.0, availableHeight)
            : (availableHeight * heightFactor).clamp(0.0, availableHeight);

        return Stack(
          children: [
            // Dibuja la ola en la parte inferior del espacio disponible.
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ClipPath(
                  clipper: _BottomWaveClipper(),
                  child: Container(
                    width: double.infinity,
                    height: waveHeight,
                    color: AppTheme.primaryRed,
                  ),
                ),
              ),
            ),
            // El contenido (child) se coloca de forma segura sobre el fondo.
            SafeArea(
              child: padBottomByWave
                  ? Padding(
                      padding: EdgeInsets.only(bottom: waveHeight * 0.5),
                      child: child,
                    )
                  : child,
            ),
          ],
        );
      },
    );
  }
}

/// El 'clipper' que dibuja la forma de la ola no necesita ningún cambio.
class _BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.quadraticBezierTo(size.width / 2, size.height * 0.4, 0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}