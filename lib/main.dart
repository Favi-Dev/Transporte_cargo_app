// Bloque 1: Importaciones
/// Importa los paquetes y archivos necesarios para el arranque de la aplicación.
/// - `material.dart`: Widgets base de Flutter.
/// - `firebase_core.dart`: Para la inicialización de Firebase.
/// - `firebase_options.dart`: El archivo autogenerado con las credenciales de Firebase.
/// - `login_page.dart`: La pantalla inicial de la aplicación.
/// - `app_theme.dart`: El tema de diseño personalizado para toda la app.
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'theme/app_theme.dart';

// Bloque 2: Función Principal `main`
/// Función principal y punto de entrada de toda la aplicación Flutter.
/// Es `async` porque necesita esperar a que Firebase se inicialice antes de
/// poder ejecutar la interfaz de usuario de la aplicación.
void main() async {
  /// Asegura que los 'bindings' de Flutter estén inicializados. Es una línea
  /// obligatoria si se va a llamar a código asíncrono (como `Firebase.initializeApp`)
  /// antes de la función `runApp`.
  WidgetsFlutterBinding.ensureInitialized();

  /// Inicializa todos los servicios de Firebase en la aplicación, cargando las
  /// credenciales correctas desde la clase `DefaultFirebaseOptions`. Se especifica
  /// `DefaultFirebaseOptions.web` porque esta es una aplicación web.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.web,
  );

  /// Función de Flutter que "infla" el widget raíz de la aplicación (`MyApp`)
  /// y lo adjunta a la pantalla, dando inicio a la interfaz de usuario.
  runApp(const MyApp());
}

// Bloque 3: Widget Raíz `MyApp`
/// El widget raíz de toda la aplicación. Es un `StatelessWidget` porque su
/// configuración principal (título, tema, pantalla de inicio) no cambia una vez
/// que la app está en ejecución.
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  /// Bloque 4: Método build
  /// Método que construye la estructura base de la aplicación, que es un `MaterialApp`.
  @override
  Widget build(BuildContext context) {
    /// `MaterialApp` es el widget que introduce todas las funcionalidades de Material Design
    /// en la app, como la navegación entre pantallas, los temas, etc.
    /// Aquí se configura el comportamiento global de la aplicación.
    return MaterialApp(
      /// El título de la aplicación, usado por el navegador o el sistema operativo.
      title: 'Fernandez Cargo App',

      /// Aplica el tema de diseño personalizado que definimos en la clase `AppTheme`
      /// a toda la aplicación, asegurando una estética consistente en todos los widgets.
      theme: AppTheme.theme,

      /// Elimina la cinta de "Debug" que aparece en la esquina superior derecha.
      debugShowCheckedModeBanner: false,

      /// Define cuál será la primera pantalla que el usuario verá al abrir la aplicación,
      /// en este caso, la `LoginPage`.
      home: const LoginPage(),
    );
  }
}
