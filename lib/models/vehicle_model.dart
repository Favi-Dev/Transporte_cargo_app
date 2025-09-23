// Bloque 1: Importaciones
/// Importa el paquete de Cloud Firestore para tener acceso a sus clases,
/// como `DocumentSnapshot`, que es necesaria para leer documentos de la base de datos.
import 'package:cloud_firestore/cloud_firestore.dart';

// Bloque 2: Definición de la Clase
/// Define la estructura de un objeto `VehicleModel` (Vehículo) en la aplicación.
/// Cada propiedad corresponde a un campo en un documento de la colección `vehicles` en Firestore.
/// `id` representa la patente del vehículo, que es también el ID del documento.
class VehicleModel {
  final String id;
  final String brand;
  final String model;
  final int year;
  final String color;
  final String type;
  final String status;
  final String owner;
  final String? assignedTo;

  // Bloque 3: Constructor
  /// Constructor principal de la clase. Permite crear una instancia de `VehicleModel`
  /// de forma programática dentro de la aplicación.
  VehicleModel({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.color,
    required this.type,
    required this.status,
    required this.owner,
    this.assignedTo,
  });

  // Bloque 4: Factory Constructor fromFirestore
  /// Constructor de fábrica que actúa como un "traductor" desde Firestore a la app.
  /// Recibe un `DocumentSnapshot` y lo convierte en un objeto `VehicleModel` fácil de manejar.
  factory VehicleModel.fromFirestore(DocumentSnapshot doc) {
    // Se valida que el documento no esté vacío para prevenir errores.
    final data = doc.data();
    if (data == null) {
      throw Exception('Documento de vehículo sin datos: ${doc.id}');
    }
    Map<String, dynamic> map = data as Map<String, dynamic>;

    // Se crea el objeto, usando valores por defecto (`??`) para los campos
    // que son obligatorios en el modelo, garantizando que la app no falle si un dato falta.
    return VehicleModel(
      id: doc.id,
      brand: map['brand'] ?? '',
      model: map['model'] ?? '',
      year: map['year'] ?? 0,
      color: map['color'] ?? '',
      type: map['type'] ?? '',
      status: map['status'] ?? 'disponible',
      owner: map['owner'] ?? '',
      assignedTo: map['assigned_to'],
    );
  }

  // Bloque 5: Método toFirestore
  /// Realiza la operación inversa al factory. Convierte este objeto `VehicleModel` de vuelta
  /// a un `Mapa` (`Map<String, dynamic>`). Este es el formato que Firestore
  /// necesita para poder guardar o actualizar un documento en la base de datos.
  Map<String, dynamic> toFirestore() {
    return {
      'brand': brand,
      'model': model,
      'year': year,
      'color': color,
      'owner': owner,
      'type': type,
      'status': status,
      'assigned_to': assignedTo,
    };
  }
}
