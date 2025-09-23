// Bloque 1: Importaciones
/// Importaciones necesarias para la pantalla de perfil, incluyendo:
/// - Widgets de Flutter, servicios de Firebase (Auth, Firestore, Storage).
/// - Paquetes externos como `image_picker` para seleccionar imágenes e `intl` para formatear fechas.
/// - Los modelos de datos, el servicio de Firestore y el scaffold personalizado.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/trip_model.dart';
import '../services/firestore_service.dart';
import 'login_page.dart';
import 'audit_log_screen.dart';
import '../widgets/curved_background_scaffold.dart';

// Bloque 2: Definición del StatefulWidget
/// Define la `ProfileScreen`, una pantalla con estado (`StatefulWidget`) que muestra
/// los detalles de un usuario, su historial de viajes (si es chofer), y permite
/// acciones como cambiar la foto de perfil y cerrar sesión.
/// Recibe el `UserModel` del usuario a mostrar, lo que la hace reutilizable.
class ProfileScreen extends StatefulWidget {
  final UserModel user;
  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

// Bloque 3: Clase de Estado
/// Clase que maneja el estado y la lógica de la `ProfileScreen`.
class _ProfileScreenState extends State<ProfileScreen> {
  // Bloque 3.1: Variables de Estado
  /// Declara las variables de estado.
  /// - `_firestoreService`: Para acceder a la lógica de negocio.
  /// - `_isUploading`: Una bandera para controlar si se está subiendo una foto de perfil
  ///   y mostrar un indicador de carga en la UI.
  final FirestoreService _firestoreService = FirestoreService();
  bool _isUploading = false;

  // Bloque 3.2: Método _signOut
  /// Método asíncrono que se encarga de cerrar la sesión del usuario actual en
  /// Firebase Authentication y lo redirige a la `LoginPage`, eliminando el
  /// historial de navegación anterior para que no pueda volver atrás.
  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  // Nuevo método para mostrar el diálogo de confirmación
  void _showSignOutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar la sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _signOut(context);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  // Bloque 3.3: Método _pickAndUploadImage
  /// Método asíncrono que gestiona el flujo completo para cambiar la foto de perfil.
  /// 1. Activa el estado de carga (`_isUploading`).
  /// 2. Usa el paquete `image_picker` para abrir la galería del dispositivo.
  /// 3. Si se selecciona un archivo, lee sus datos en bytes.
  /// 4. Llama al método `uploadProfilePicture` del `FirestoreService` para subir la imagen.
  /// 5. Muestra un `SnackBar` de éxito o error.
  /// 6. Desactiva el estado de carga al finalizar.
  Future<void> _pickAndUploadImage() async {
    setState(() => _isUploading = true);
    try {
      final picker = ImagePicker();
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final Uint8List fileBytes = await pickedFile.readAsBytes();
        await _firestoreService.uploadProfilePicture(
            widget.user.uid, fileBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Foto de perfil actualizada con éxito.'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // Bloque 4: Método build
  /// Método principal que construye la interfaz visual del perfil.
  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    // --- PRUEBA DE DEPURACIÓN ---
    print("--- Construyendo ProfileScreen para: ${user.name} ---");
    print(">>> El rol que la app está leyendo es: '${user.role}' <<<");
    print("--------------------------------------------------");
    // --- FIN DE LA PRUEBA ---

    return CurvedBackgroundScaffold(
      appBar: AppBar(title: Text('Perfil de ${user.name}')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          /// Bloque 4.2: Widget de Foto de Perfil
          /// Construye la sección de la foto de perfil. Usa un `Stack` para superponer:
          /// - El `CircleAvatar` (que muestra la imagen o un ícono por defecto).
          /// - Un `CircularProgressIndicator` (visible durante la subida).
          /// - Un `IconButton` para activar la función `_pickAndUploadImage`.
          Container(
            padding: const EdgeInsets.all(16.0),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  backgroundImage: user.profilePictureUrl != null &&
                          user.profilePictureUrl!.isNotEmpty
                      ? NetworkImage(user.profilePictureUrl!) as ImageProvider
                      : null,
                  child: user.profilePictureUrl == null ||
                          user.profilePictureUrl!.isEmpty
                      ? Icon(Icons.person,
                          size: 80, color: Colors.white.withOpacity(0.8))
                      : null,
                ),
                if (_isUploading)
                  // Muestra un loader que cubre el avatar mientras se sube la imagen
                  const Positioned.fill(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                else
                  // Muestra el botón de editar si no se está subiendo
                  Material(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _pickAndUploadImage,
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.edit, color: Colors.white, size: 20),
                      ),
                    ),
                  )
              ],
            ),
          ),

          /// Bloque 4.3: Tarjeta de Información del Usuario
          /// Muestra los datos personales básicos del usuario (nombre, RUT, etc.)
          /// dentro de una `Card` estilizada, usando `ListTile`s para un formato ordenado.
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person, color: Colors.white70),
                    title: const Text('Nombre',
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text(user.name,
                        style: const TextStyle(color: Colors.white70)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.badge, color: Colors.white70),
                    title: const Text('RUT',
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text(user.rut,
                        style: const TextStyle(color: Colors.white70)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.email, color: Colors.white70),
                    title: const Text('Email de Contacto',
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                        user.email.isNotEmpty ? user.email : 'No registrado',
                        style: const TextStyle(color: Colors.white70)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone, color: Colors.white70),
                    title: const Text('Teléfono',
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                        user.phone.isNotEmpty ? user.phone : 'No registrado',
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),

          /// Bloque 4.4: Historial de Viajes
          /// Eliminar este bloque condicional y su contenido para simplificar la pantalla de perfil.
          /// Antes:
          /// if (widget.user.role != 'admin') ...[
          ///   Padding(
          ///     padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          ///     child: Text('Historial de Viajes', style: Theme.of(context).textTheme.headlineSmall),
          ///   ),
          ///   StreamBuilder<QuerySnapshot>(
          ///     stream: FirebaseFirestore.instance
          ///         .collection('trips')
          ///         .where('driverId', isEqualTo: widget.user.uid)
          ///         .orderBy('startTime', descending: true)
          ///         .limit(20)
          ///         .snapshots(),
          ///     builder: (context, snapshot) {
          ///       if (snapshot.connectionState == ConnectionState.waiting) {
          ///         return const Center(child: CircularProgressIndicator());
          ///       }
          ///       if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          ///         return const Center(child: Padding(
          ///           padding: EdgeInsets.all(16.0),
          ///           child: Text('No hay viajes registrados.'),
          ///         ));
          ///       }
          ///       return Column(
          ///         children: snapshot.data!.docs.map((doc) {
          ///           final trip = TripModel.fromFirestore(doc);
          ///           final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
          ///           return Card(
          ///             margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ///             child: ListTile(
          ///               leading: const Icon(Icons.route, color: Colors.white70),
          ///               title: Text('Vehículo: ${trip.vehicleId.toUpperCase()}', style: const TextStyle(color: Colors.white)),
          ///               subtitle: Text(
          ///                 'Inicio: ${dateFormat.format(trip.startTime.toDate())}\nFin: ${trip.endTime != null ? dateFormat.format(trip.endTime!.toDate()) : "En curso"}',
          ///                 style: const TextStyle(color: Colors.white70)
          ///               ),
          ///               isThreeLine: true,
          ///             ),
          ///           );
          ///         }).toList(),
          ///       );
          ///     },
          ///   ),
          /// ],

          // --- Botón solo para el Super Admin ---
          if (user.role == 'super_admin') ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('Ver Registros de Auditoría'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AuditLogScreen()),
                  );
                },
              ),
            ),
          ],

          // --- Botón de cerrar sesión ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => _showSignOutConfirmationDialog(context),
              child: const Text('Cerrar Sesión'),
            ),
          ),
        ],
      ),
    );
  }
}
