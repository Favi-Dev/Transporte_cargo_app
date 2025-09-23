// Bloque 1: Importaciones
/// Importa los paquetes necesarios para usar funcionalidades de Firebase Firestore,
/// específicamente la clase `Timestamp` para manejar fechas y `DocumentSnapshot`
/// para leer datos de la base de datos.
import 'package:cloud_firestore/cloud_firestore.dart';

// Bloque 2: Definición de la Clase
/// Define la estructura de un objeto `TripModel` (Viaje) dentro de la aplicación.
/// Cada propiedad (`final String`, `final Timestamp`, etc.) corresponde a un campo
/// que se espera encontrar en un documento de la colección 'trips' en Firestore.
class TripModel {
  final String driverId;
  final String driverName;
  final Timestamp startTime;
  final Timestamp?
      endTime; // El '?' indica que este valor puede ser nulo (ej. en un viaje en curso)
  final String vehicleId;
  final String? semiId; // También puede ser nulo si el viaje no incluyó un semi

  // Bloque 3: Constructor
  /// Constructor principal de la clase. Permite crear una instancia de `TripModel`
  /// desde otras partes de la aplicación, proporcionando todos los valores necesarios.
  /// Los campos marcados como `required` son obligatorios.
  TripModel({
    required this.driverId,
    required this.driverName,
    required this.startTime,
    this.endTime,
    required this.vehicleId,
    this.semiId,
  });

  // Bloque 4: Factory Constructor fromFirestore
  /// Constructor "de fábrica" que sirve como un "traductor".
  /// Toma un `DocumentSnapshot` (los datos crudos tal como vienen de Firestore)
  /// y lo convierte en un objeto `TripModel` estructurado y fácil de usar en Dart.
  /// Incluye valores por defecto (usando `??`) para proteger la app contra errores
  /// si algún campo en la base de datos estuviera vacío o nulo.
  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return TripModel(
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? '',
      startTime: data['startTime'] ?? Timestamp.now(),
      endTime: data['endTime'],
      vehicleId: data['vehicleId'] ?? '',
      semiId: data['semiId'],
    );
  }

  // Bloque 5: Método toFirestore
  /// Realiza la operación inversa al factory. Convierte un objeto `TripModel` que existe
  /// en la aplicación de vuelta a un formato de `Mapa` (`Map<String, dynamic>`).
  /// Este es el formato que Firestore entiende y necesita para poder guardar
  /// o actualizar un documento en la base de datos.
  Map<String, dynamic> toFirestore() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'startTime': startTime,
      'endTime': endTime,
      'vehicleId': vehicleId,
      'semiId': semiId,
    };
  }
}
