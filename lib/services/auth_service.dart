// Bloque 1: Importaciones
/// Importa los paquetes de Firebase necesarios para la autenticación y la base de datos.
/// - `cloud_firestore.dart`: Para interactuar con la base de datos Firestore (colección 'users').
/// - `firebase_auth.dart`: Para manejar el inicio de sesión y la gestión de usuarios.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Bloque 2: Definición de la Clase de Utilidades
/// Define una clase de utilidades (`Utils`) para la autenticación.
/// Al ser una clase con métodos y propiedades `static`, no es necesario crear una
/// instancia de `AuthUtils` para usar sus funciones. Se accede directamente a ellas,
/// por ejemplo: `AuthUtils.login(...)`.
class AuthUtils {
  /// Bloque 2.1: Propiedades Estáticas
  /// Instancias estáticas de `FirebaseAuth` y `FirebaseFirestore`. Esto permite
  /// tener un único punto de acceso a estos servicios en toda la aplicación,
  /// evitando inicializarlos múltiples veces.
  static FirebaseAuth auth = FirebaseAuth.instance;
  static FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Bloque 2.2: Método de Login
  /// Método estático y asíncrono para gestionar el inicio de sesión del usuario.
  /// Realiza un proceso de dos pasos:
  /// 1. Autentica al usuario con su email y contraseña contra Firebase Authentication.
  /// 2. Si la autenticación es exitosa, busca el documento del usuario en la
  ///    colección 'users' de Firestore usando su UID y devuelve sus datos.
  ///
  /// Utiliza un bloque `try-catch` para manejar errores comunes de autenticación
  /// (ej. contraseña incorrecta, usuario no encontrado).
  ///
  /// @param email El email del usuario para iniciar sesión (en nuestro caso, el RUT formateado).
  /// @param password La contraseña del usuario.
  /// @return Un `Future` que resuelve a un `Map<String, dynamic>` con los datos del
  ///         documento del usuario si el login es exitoso, o `null` si falla.
  static Future<Map<String, dynamic>?> login(
      String email, String password) async {
    try {
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Obtener documento del usuario en Firestore
        DocumentSnapshot userDoc =
            await firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          return userDoc.data() as Map<String, dynamic>;
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('Error de login: $e');
      return null;
    }
  }
}
