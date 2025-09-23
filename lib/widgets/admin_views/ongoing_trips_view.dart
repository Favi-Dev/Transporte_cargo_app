// Bloque 1: Importaciones
/// Importa los paquetes y archivos necesarios para esta vista.
/// - `material.dart`: Para los widgets de Flutter.
/// - `cloud_firestore.dart`: Para conectarse a la base de datos Firestore.
/// - `vehicle_model.dart`: Para convertir los documentos de Firestore a objetos VehicleModel.
/// - `assigned_driver_card.dart`: El widget reutilizable que muestra la información
///   de un viaje agrupado por chofer.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/vehicle_model.dart';
import '../assigned_driver_card.dart';

// Bloque 2: Definición del StatelessWidget
/// Define la vista `OngoingTripsView` como un `StatelessWidget`.
/// No necesita manejar estado por sí mismo, ya que toda la información
/// se obtiene en tiempo real desde Firestore a través de un `StreamBuilder`.
class OngoingTripsView extends StatelessWidget {
  const OngoingTripsView({Key? key}) : super(key: key);

  /// Bloque 3: Método build
  /// Método principal que construye la interfaz de usuario de la pestaña "En Curso".
  @override
  Widget build(BuildContext context) {
    /// Bloque 3.1: StreamBuilder
    /// Es el corazón de esta vista. Se conecta a la colección `vehicles` de Firestore
    /// y escucha cambios en tiempo real, pero solo para los documentos cuyo
    /// `status` sea 'ocupado'.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vehicles')
          .where('status', isEqualTo: 'ocupado')
          .snapshots(),
      builder: (context, snapshot) {
        /// Bloque 3.1.1: Manejo de Estados de Carga
        /// Muestra un indicador de carga mientras se esperan los datos,
        /// un mensaje de error si la consulta falla, o un mensaje informativo
        /// si no hay viajes en curso.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
              child: Text('Ocurrió un error al cargar los viajes.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No hay viajes en curso actualmente.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        /// Bloque 3.1.2: Procesamiento y Agrupación de Datos
        /// Esta es la lógica clave para agrupar los vehículos.
        /// 1. Convierte todos los documentos de vehículos 'ocupados' en una lista de objetos `VehicleModel`.
        /// 2. Crea un `Mapa` (`groupedByDriver`) donde cada clave es el UID de un chofer.
        /// 3. Itera sobre los vehículos ocupados y los añade a la lista correspondiente
        ///    dentro del mapa, agrupándolos efectivamente por chofer.
        final occupiedVehicles = snapshot.data!.docs
            .where((doc) => doc.data() != null)
            .map((doc) => VehicleModel.fromFirestore(doc))
            .toList();

        final Map<String, List<VehicleModel>> groupedByDriver = {};
        for (final vehicle in occupiedVehicles) {
          if (vehicle.assignedTo != null && vehicle.assignedTo!.isNotEmpty) {
            if (groupedByDriver.containsKey(vehicle.assignedTo)) {
              groupedByDriver[vehicle.assignedTo]!.add(vehicle);
            } else {
              groupedByDriver[vehicle.assignedTo!] = [vehicle];
            }
          }
        }

        /// Bloque 3.1.3: Construcción de la Lista
        /// Crea un `ListView` que itera sobre el mapa de viajes agrupados.
        /// Por cada entrada en el mapa (cada chofer), renderiza un widget `AssignedDriverCard`,
        /// pasándole el UID del chofer y la lista de vehículos que tiene a su cargo.
        return ListView(
          padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
          children: groupedByDriver.entries.map((entry) {
            return AssignedDriverCard(
              driverUid: entry.key,
              assignedVehicles: entry.value,
            );
          }).toList(),
        );
      },
    );
  }
}
