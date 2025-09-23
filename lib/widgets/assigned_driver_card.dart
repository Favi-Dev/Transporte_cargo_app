// Bloque 1: Importaciones
/// Importaciones necesarias para la tarjeta de viaje en curso.
/// - `material.dart`, `cloud_firestore.dart`, `intl.dart`: Paquetes base.
/// - `user_model.dart`, `vehicle_model.dart`: Para estructurar los datos.
/// - `firestore_service.dart`: Para la lógica de negocio como la liberación forzosa.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../services/firestore_service.dart';

// Bloque 2: Definición del StatelessWidget
/// Define la `AssignedDriverCard`, un widget `Stateless` y reutilizable que muestra
/// un resumen completo de un viaje en curso. Es la tarjeta principal en la pestaña
/// "En Curso" del dashboard del administrador.
/// Recibe el UID del chofer y la lista de sus vehículos asignados para poder renderizarse.
class AssignedDriverCard extends StatelessWidget {
  final String driverUid;
  final List<VehicleModel> assignedVehicles;

  const AssignedDriverCard({
    Key? key,
    required this.driverUid,
    required this.assignedVehicles,
  }) : super(key: key);

  /// Bloque 2.1: Método _showConfirmationDialog
  /// Construye y muestra un diálogo de alerta (`AlertDialog`) para que el administrador
  /// confirme la liberación forzosa de un viaje. Utiliza un `StatefulBuilder`
  /// para poder manejar un estado de carga (`isLoading`) localmente dentro del diálogo,
  /// mostrando un `CircularProgressIndicator` en el botón de confirmación
  /// mientras se procesa la solicitud al `FirestoreService`.
  void _showConfirmationDialog(BuildContext context, String driverName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirmar Liberación Forzosa'),
              content: Text(
                  '¿Estás seguro de que quieres liberar TODOS los vehículos asignados a $driverName?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed:
                      isLoading ? null : () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: isLoading
                      ? null
                      : () async {
                          setDialogState(() => isLoading = true);

                          try {
                            final service = FirestoreService();
                            await service.forceReleaseVehicleForDriver(
                                driverUid: driverUid);

                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Vehículos liberados con éxito.'),
                                  backgroundColor: Colors.green),
                            );
                          } catch (e) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error al liberar: $e'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Bloque 2.2: Método _formatTimestamp
  /// Función de utilidad simple para formatear un objeto `Timestamp` de Firestore
  /// a un `String` legible con formato `HH:mm`. Devuelve 'No registrada' si el timestamp es nulo.
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No registrada';
    final dt = timestamp.toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Bloque 3: Método build
  /// Método principal que construye la interfaz visual de la tarjeta.
  @override
  Widget build(BuildContext context) {
    /// Bloque 3.1: Procesamiento de Datos
    /// Procesa la lista `assignedVehicles` para identificar y separar el vehículo
    /// principal (tracto/camión) del semi-remolque, usando el helper `firstOrNull`.
    final VehicleModel? tracto = assignedVehicles
        .where((v) => v.type == 'tracto_camion' || v.type == 'camion')
        .firstOrNull;
    final VehicleModel? semi =
        assignedVehicles.where((v) => v.type == 'semi_remolque').firstOrNull;

    /// Bloque 3.2: Construcción de la UI
    /// - La tarjeta base es un `Card` estilizado.
    /// - Usa un `FutureBuilder` para buscar de forma asíncrona los datos del chofer
    ///   (nombre, hora de salida) en la colección `users` a partir del `driverUid`.
    ///   Maneja los estados de carga y error (ej. si el chofer fue eliminado).
    /// - El widget principal es un `InkWell`, que hace que toda la tarjeta sea 'tocable'
    ///   para activar el diálogo de liberación.
    /// - Dentro, un `Column` y `ListTile`s organizan la información del chofer, la hora
    ///   y los detalles de cada vehículo asignado, creando un resumen claro.
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('users').doc(driverUid).get(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(12.0),
              child: Center(child: LinearProgressIndicator()),
            );
          }
          if (!userSnapshot.data!.exists || userSnapshot.data!.data() == null) {
            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(height: 8),
                  Text(
                    'Chofer no encontrado (eliminado de la base de datos)',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          final user = UserModel.fromFirestore(userSnapshot.data!);
          final departureTime = _formatTimestamp(user.departureTime);

          return InkWell(
            onTap: () => _showConfirmationDialog(context, user.name),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white70, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white),
                        ),
                      ),
                      const Icon(Icons.timer_outlined,
                          color: Colors.white60, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Salida: $departureTime',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white60),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Colors.white24),
                  if (tracto != null)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.local_shipping,
                          color: Colors.white70),
                      // CAMBIO: Patente como título, marca/modelo/año como subtítulo
                      title: Text(
                        tracto.id.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${toBeginningOfSentenceCase(tracto.brand)} ${toBeginningOfSentenceCase(tracto.model)} (${tracto.year})',
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),
                  if (semi != null)
                    ListTile(
                      dense: true,
                      leading:
                          const Icon(Icons.rv_hookup, color: Colors.white70),
                      title: Text(
                        semi.id.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${toBeginningOfSentenceCase(semi.brand)} ${toBeginningOfSentenceCase(semi.model)} (${semi.year})',
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bloque 4: Extensión FirstOrNull
/// Extensión útil sobre la clase `Iterable` (la base de las Listas en Dart).
/// Añade el método `.firstOrNull` que devuelve el primer elemento de una lista
/// o `null` si la lista está vacía. Esto es más seguro que usar `.first`, que
/// lanzaría un error en una lista vacía, y es una buena práctica de programación defensiva.
extension FirstOrNullExtension<E> on Iterable<E> {
  E? firstOrNullWhere(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }

  E? get firstOrNull {
    Iterator<E> it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
