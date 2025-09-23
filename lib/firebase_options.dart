// Bloque 1: Cabecera e Importaciones
/// Archivo autogenerado por la herramienta FlutterFire CLI.
/// No se debe modificar manualmente, ya que se regenera al cambiar la configuración de Firebase.
/// Contiene la configuración necesaria para conectar la aplicación Flutter con los
/// diferentes proyectos y plataformas de Firebase (web, Android, iOS, etc.).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Bloque 2: Clase Principal
/// Clase de utilidad que centraliza las 'llaves' o credenciales de conexión
/// para cada plataforma (web, Android, etc.) en la que la aplicación puede ejecutarse.
///
/// El ejemplo de uso muestra cómo se debe inicializar Firebase en `main.dart`
/// usando esta clase para que la app se conecte al proyecto de Firebase correcto
/// según dónde se esté ejecutando.
class DefaultFirebaseOptions {
  /// Bloque 3: Getter `currentPlatform`
  /// Un `getter` estático inteligente que determina en qué plataforma se está
  /// ejecutando la aplicación actualmente y devuelve el objeto `FirebaseOptions`
  /// correspondiente. Este es el método que se usa en `main.dart` para
  /// inicializar Firebase de forma dinámica.
  static FirebaseOptions get currentPlatform {
    /// 3.1: Comprobación de Plataforma Web
    /// `kIsWeb` es una constante de Flutter que es `true` si la app se compila para la web.
    /// Si es así, devuelve las credenciales definidas en la variable `web`.
    if (kIsWeb) {
      return web;
    }

    /// 3.2: Comprobación de Plataformas Nativas
    /// Si no es web, utiliza un `switch` para revisar la plataforma nativa
    /// (Android, iOS, etc.) y devolver las credenciales correctas.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;

      /// 3.3: Manejo de Plataformas no Soportadas
      /// Para las plataformas que no hemos configurado (iOS, macOS, etc.), lanza un
      /// error claro y descriptivo. Esto previene que la app intente ejecutarse
      /// en una plataforma no preparada y ayuda a los desarrolladores a saber que
      /// necesitan configurar las credenciales para esa plataforma usando FlutterFire CLI.
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Bloque 4: Credenciales para la Web
  /// Objeto estático y constante que contiene las credenciales específicas para la
  /// versión **web** de la aplicación, apuntando al proyecto de Firebase
  /// `gestionfernandezcargo`.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCxm92ldt2XDH4sGSxc_4VL7EyndBt6DrY',
    appId: '1:121208085842:web:cf9057d6f20c3d627c6e8b',
    messagingSenderId: '121208085842',
    projectId: 'gestionfernandezcargo',
    authDomain: 'gestionfernandezcargo.firebaseapp.com',
    storageBucket:
        'gestionfernandezcargo.appspot.com', // Corregido para formato estándar
    measurementId: 'G-XVLW2GQ85F',
  );

  /// Bloque 5: Credenciales para Android
  /// Objeto estático y constante que contiene las credenciales para una posible
  /// versión de **Android**.
  /// **Nota:** Los datos de este objeto (como el `projectId: 'fernandezcargo-152c2'`)
  /// parecen apuntar a un proyecto de Firebase diferente al de la web. Es importante
  /// asegurar que esto sea intencional y no un error de configuración.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCLFwrLsXJNEf6fHNWXJtIlECwK2UwDoLM',
    appId: '1:631286543687:android:a77e6fb54af39445e24862',
    messagingSenderId: '631286543687',
    projectId: 'fernandezcargo-152c2',
    storageBucket:
        'fernandezcargo-152c2.appspot.com', // Corregido para formato estándar
  );
}
