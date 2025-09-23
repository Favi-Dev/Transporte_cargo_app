// Bloque 1: Importaciones
/// Importaciones necesarias para construir la pantalla principal, incluyendo:
/// - Widgets de Flutter, servicios de Firebase (Auth y Firestore).
/// - Las pantallas que se mostrarán en la barra de navegación (`home_page.dart`, `profile_screen.dart`).
/// - El modelo de datos del usuario (`user_model.dart`).
/// - El tema de la aplicación (`app_theme.dart`) para la consistencia visual.
import 'package:fernandez_cargo_app/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'profile_screen.dart';
import '../theme/app_theme.dart';

// Bloque 2: Definición del StatefulWidget
/// Define la `MainScreen`, que actúa como el 'contenedor' principal de la aplicación
/// después del login. Es un `StatefulWidget` porque necesita gestionar la pestaña activa
/// y escuchar los datos del usuario en tiempo real para ser una app reactiva.
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// Bloque 3: Clase de Estado
/// Clase que maneja el estado, la lógica y la interfaz de `MainScreen`.
class _MainScreenState extends State<MainScreen> {
  // Bloque 3.1: Variables de Estado
  /// Declara las variables de estado de la pantalla.
  /// - `_selectedIndex`: Guarda el índice de la pestaña activa (0 para Inicio, 1 para Perfil).
  /// - `_userStream`: Un flujo de datos (`Stream`) que se mantiene conectado a Firestore para
  ///   recibir actualizaciones del documento del usuario actual en tiempo real.
  int _selectedIndex = 0;
  Stream<DocumentSnapshot>? _userStream;

  // Bloque 3.2: Método initState
  /// Método del ciclo de vida que se ejecuta una sola vez al crear la pantalla.
  /// Su función es obtener el UID del usuario actualmente autenticado e inicializar
  /// el `_userStream` para que se 'suscriba' a los cambios de su documento en la
  /// colección `users`.
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    }
  }

  // Bloque 3.3: Método _onItemTapped
  /// Función que se llama cuando el usuario toca un ícono en la `BottomNavigationBar`.
  /// Actualiza `_selectedIndex` con el nuevo índice y llama a `setState` para que
  /// la pantalla se redibuje y muestre la página correspondiente.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Bloque 4: Método build
  /// Método principal que construye la interfaz de la pantalla.
  /// Es el corazón de la pantalla reactiva, usando un `StreamBuilder`.
  @override
  Widget build(BuildContext context) {
    /// Bloque 4.1: StreamBuilder
    /// Utiliza un `StreamBuilder` para construir la UI de forma reactiva. Escucha el `_userStream`
    /// y se redibuja automáticamente según el estado de los datos:
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        /// 4.1.1: Estado de Carga
        /// Mientras espera los datos iniciales de Firestore, muestra un indicador de carga circular.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryRed,
              ),
            ),
          );
        }

        /// 4.1.2: Estado de Error o Sin Datos
        /// Si ocurre un error, el stream no trae datos o el documento del usuario no existe,
        /// muestra una pantalla de error para informar al usuario.
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(
                child: Text(
                    'Error al cargar datos del usuario.\nRevisa la consola de depuración.')),
          );
        }

        /// 4.1.3: Estado de Éxito
        /// Cuando recibe los datos del documento (`snapshot.data`), los convierte en un `UserModel`.
        /// Define la lista de pantallas (`pages`) que se pueden navegar, pasándoles el modelo de
        /// usuario actualizado. Finalmente, construye el `Scaffold` con la `BottomNavigationBar`,
        /// mostrando en el `body` la página activa según el `_selectedIndex`.
        final userModel = UserModel.fromFirestore(snapshot.data!);

        final List<Widget> pages = [
          HomePage(user: userModel),
          ProfileScreen(user: userModel),
        ];

        return Scaffold(
          body: pages[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          ),
        );
      },
    );
  }
}
