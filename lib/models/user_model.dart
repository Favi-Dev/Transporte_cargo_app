// Bloque 1: Importaciones
/// Importa los paquetes de Firebase Firestore para poder utilizar tipos de datos
/// específicos de Firestore, como `DocumentSnapshot` y `Timestamp`.
import 'package:cloud_firestore/cloud_firestore.dart';

// Bloque 2: Definición de la Clase
/// Define la estructura de un objeto `UserModel` (Usuario) dentro de la aplicación.
/// Cada propiedad `final` representa un campo del documento de un usuario
/// en la colección `users` de Firestore. Las propiedades con `?` son opcionales (pueden ser nulas).
class UserModel {
  final String uid;
  final String name;
  final String role;
  final String rut;
  final String email;
  final String phone;
  final bool onRoute;
  final String? profilePictureUrl;
  final String? currentVehicle;
  final String? currentSemi;
  final Timestamp? departureTime;

  // Bloque 3: Constructor
  /// Constructor principal de la clase. Permite crear una instancia de `UserModel`
  /// de forma programática, por ejemplo, para pruebas o al crear un nuevo usuario.
  /// Requiere que se proporcionen todos los campos que no pueden ser nulos.
  UserModel({
    required this.uid,
    required this.name,
    required this.role,
    required this.rut,
    required this.email,
    required this.phone,
    required this.onRoute,
    this.profilePictureUrl,
    this.currentVehicle,
    this.currentSemi,
    this.departureTime,
  });

  // Bloque 4: Factory Constructor fromFirestore
  /// Constructor "de fábrica" que convierte un `DocumentSnapshot` (los datos crudos
  /// que vienen de Firestore) en un objeto `UserModel` que la aplicación puede usar.
  /// Este método es fundamental para leer datos de la base de datos.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    // Primero, se obtienen los datos del documento.
    final data = doc.data();
    // Se añade una validación importante: si el documento no tiene datos,
    // se lanza una excepción para notificar el problema y evitar que la app falle.
    if (data == null) {
      throw Exception('Documento de usuario sin datos: ${doc.id}');
    }
    // Se asegura que los datos sean del tipo correcto (un Mapa).
    Map<String, dynamic> map = data as Map<String, dynamic>;

    // Se crea y devuelve el objeto UserModel, asignando cada valor del mapa
    // a la propiedad correspondiente.
    return UserModel(
      uid: doc.id, // El UID se toma directamente del ID del documento.
      name: map['name'] ??
          '', // El operador '??' asigna un valor por defecto si el campo no existe.
      role: map['role'] ?? '',
      rut: map['rut'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      onRoute: map['on_route'] ?? false,
      profilePictureUrl: map['profile_picture_url']
          ?.toString(), // Convierte a String si no es nulo.
      currentVehicle: map['current_vehicle']?.toString(),
      currentSemi: map['current_semi']?.toString(),
      // Se comprueba explícitamente que el dato sea un Timestamp antes de asignarlo.
      departureTime:
          map['departure_time'] is Timestamp ? map['departure_time'] : null,
    );
  }
}
