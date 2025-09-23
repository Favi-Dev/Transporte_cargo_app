// Bloque 1: Importaciones
/// Importa los paquetes necesarios:
/// - `material.dart`: Para los widgets de Flutter, como Scaffold, Stack, etc.
/// - `app_theme.dart`: Para acceder a los colores personalizados de la app, como `primaryRed`.
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Bloque 2: Definición del StatelessWidget
/// Define un widget `Stateless` personalizado y reutilizable que actúa como una
/// plantilla de pantalla para toda la aplicación. Su propósito es encapsular el
/// diseño de fondo común (la curva roja) para no tener que repetir este código
/// en cada pantalla nueva.
///
/// Acepta los mismos parámetros que un `Scaffold` normal, como `body`, `appBar` y
/// `floatingActionButton`, para que su uso sea familiar e intuitivo.
class CurvedBackgroundScaffold extends StatelessWidget {
  final Widget body;
  final AppBar? appBar;
  final Widget? floatingActionButton;

  const CurvedBackgroundScaffold({
    Key? key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
  }) : super(key: key);

  /// Bloque 3: Método build
  /// Construye la interfaz del `CurvedBackgroundScaffold`.
  /// - Utiliza un `Scaffold` como base para la estructura de la pantalla.
  /// - El cuerpo (`body`) es un `Stack`, que permite superponer widgets uno encima de otro.
  /// - En el fondo del `Stack`, se posiciona un `Container` rojo que es recortado por
  ///   `_BottomWaveClipper` para darle la forma de ola.
  /// - Encima de la ola, se coloca el `body` principal de la pantalla, envuelto en un
  ///   `SafeArea` para evitar que el contenido se superponga con elementos del
  ///   sistema operativo (como la barra de estado o el 'notch' de los móviles).
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: _BottomWaveClipper(),
              child: Container(
                height: size.height * 0.2,
                color: AppTheme.primaryRed,
              ),
            ),
          ),
          SafeArea(child: body),
        ],
      ),
    );
  }
}

// Bloque 4: Clase _BottomWaveClipper
/// Una clase privada que extiende `CustomClipper<Path>`. Su única responsabilidad
/// es definir la forma geométrica de la curva. El método `getClip` dibuja un
/// `Path` (trazado) que recorta su widget hijo (el `Container` rojo) para darle
/// la apariencia de una ola cóncava, usando una curva de Bézier cuadrática.
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

  /// Indica a Flutter que no es necesario volver a dibujar la curva si el widget no cambia de tamaño.
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
