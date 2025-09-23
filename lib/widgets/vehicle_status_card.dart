// Bloque 1: Importaciones
/// Importa todos los paquetes, modelos, pantallas y utilidades necesarias.
/// - `material.dart`, `cloud_firestore.dart`: Paquetes base de Flutter y Firebase.
/// - `vehicle_model.dart`, `user_model.dart`: Para estructurar los datos.
/// - `firestore_service.dart`: Para la lógica de negocio (liberación forzosa).
/// - `color_utils.dart`: Para la burbuja de color.
/// - `vehicle_form_screen.dart`: La pantalla de destino para editar un vehículo.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../utils/color_utils.dart';
import '../screens/vehicle_form_screen.dart';

// Bloque 2: Definición del StatelessWidget
/// Define la `VehicleStatusCard`, un widget `Stateless` y reutilizable.
/// Su propósito es mostrar un resumen de un único vehículo en el dashboard del admin.
/// Es "inteligente" porque su apariencia y acciones cambian si el vehículo está
/// disponible u ocupado.
class VehicleStatusCard extends StatelessWidget {
  final VehicleModel vehicle;

  const VehicleStatusCard({Key? key, required this.vehicle}) : super(key: key);

  /// Bloque 2.1: Método _showConfirmationDialog
  /// Construye y muestra un diálogo de alerta para confirmar la liberación forzosa.
  /// Este método solo se llama cuando se interactúa con una tarjeta de vehículo 'ocupado'.
  /// Usa un `StatefulBuilder` para manejar el estado de carga del botón de confirmación.
  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirmar Liberación'),
              content: Text(
                  '¿Estás seguro de que quieres liberar el vehículo ${vehicle.id}? Esta acción también actualizará el estado del chofer asignado.'),
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
                            if (vehicle.assignedTo != null &&
                                vehicle.assignedTo!.isNotEmpty) {
                              await service.forceReleaseVehicleForDriver(
                                  driverUid: vehicle.assignedTo!);
                            } else {
                              throw Exception(
                                  'El vehículo no tiene un chofer asignado válido.');
                            }
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Vehículo liberado con éxito.'),
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

  // --- NUEVO: Diálogo de confirmación para borrar vehículo ---
  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
            '¿Estás seguro de que quieres eliminar permanentemente el vehículo ${vehicle.id}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
            onPressed: () async {
              try {
                await FirestoreService().deleteVehicle(vehicle.id);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Vehículo eliminado'),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                // ... manejo de error
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error al eliminar: $e'),
                      backgroundColor: Colors.red),
                );
              }
            },
          )
        ],
      ),
    );
  }

  /// Bloque 3: Método build Principal
  /// Construye la interfaz visual de la tarjeta.
  @override
  Widget build(BuildContext context) {
    /// Bloque 3.1: Lógica Visual
    /// Determina si el vehículo está disponible y asigna el color de estado correspondiente
    /// (verde para disponible, naranja para ocupado).
    final bool isAvailable = vehicle.status == 'disponible';
    final Color statusColor = isAvailable ? Colors.green : Colors.orange;

    /// Bloque 3.2: Estructura de la Tarjeta
    /// - El widget base es un `Card` que hereda el estilo oscuro del `AppTheme`.
    /// - Se envuelve en un `InkWell` para hacerlo 'tocable' (`onTap`), pero solo
    ///   si el vehículo está ocupado (para mostrar el diálogo de liberación).
    /// - Un `Column` organiza el contenido verticalmente.
    return Card(
      child: InkWell(
        onTap: isAvailable ? null : () => _showConfirmationDialog(context),
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Bloque 3.2.1: Fila Superior (Patente, Status y Botón Editar)
              /// Muestra la patente, el indicador de estado, y condicionalmente
              /// (`if (isAvailable)`) un `IconButton` para editar el vehículo
              /// solo si está disponible.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vehicle.id,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          vehicle.status.toUpperCase(),
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                      if (isAvailable)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.white70, size: 20),
                              tooltip: 'Editar Vehículo',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        VehicleFormScreen(vehicle: vehicle),
                                  ),
                                );
                              },
                            ),
                            // --- NUEVO: Botón de eliminar ---
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 20),
                              tooltip: 'Eliminar Vehículo',
                              onPressed: () =>
                                  _showDeleteConfirmationDialog(context),
                            ),
                          ],
                        ),
                    ],
                  )
                ],
              ),
              const Divider(height: 20, color: Colors.white24),

              /// Bloque 3.2.2: Fila de Detalles del Vehículo
              /// Muestra la burbuja de color (usando la función `getColorFromString`),
              /// la marca, el modelo y el año del vehículo.
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: getColorFromString(vehicle.color),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white54, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      // CAMBIO: Patente como título, marca/modelo/año como subtítulo
                      '${vehicle.id.toUpperCase()}',
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Text(
                '${vehicle.brand} ${vehicle.model} (${vehicle.year})',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 8),

              /// Bloque 3.2.3: Fila de Asignación
              /// Muestra un ícono y llama al widget `_buildAssignedToWidget` para
              /// determinar si debe mostrar "Sin asignar" o el nombre del chofer.
              Row(
                children: [
                  Icon(
                      isAvailable
                          ? Icons.directions_car_filled_outlined
                          : Icons.person,
                      color: Colors.white60,
                      size: 20),
                  const SizedBox(width: 8),
                  _buildAssignedToWidget(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bloque 3.3: Widget Auxiliar _buildAssignedToWidget
  /// Widget interno que decide qué texto mostrar en la fila de asignación.
  /// Si el vehículo está disponible, muestra "Sin asignar". Si está ocupado
  /// pero no tiene un UID válido, muestra un aviso. Si está correctamente
  /// asignado, renderiza el widget `_DriverName`.
  Widget _buildAssignedToWidget() {
    final bool isAvailable = vehicle.status == 'disponible';
    final String? assignedToUid = vehicle.assignedTo;

    if (isAvailable) {
      return Text('Sin asignar',
          style:
              TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[400]));
    }

    if (assignedToUid == null || assignedToUid.isEmpty) {
      return const Text(
        'Chofer no especificado',
        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
      );
    }

    return _DriverName(uid: assignedToUid);
  }
}

/// Bloque 4: Widget Privado _DriverName
/// Widget auxiliar que se encarga de una sola tarea: recibir un UID de un chofer,
/// buscar su documento en Firestore, y mostrar su nombre y hora de salida.
/// Usa un `FutureBuilder` para manejar la operación asíncrona de forma elegante.
class _DriverName extends StatelessWidget {
  final String uid;
  const _DriverName({Key? key, required this.uid}) : super(key: key);

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Cargando...',
              style: TextStyle(color: Colors.white70));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Chofer no encontrado',
              style: TextStyle(color: Colors.red));
        }

        final user = UserModel.fromFirestore(snapshot.data!);
        final departureTime = _formatTimestamp(user.departureTime);

        return RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context)
                .style
                .copyWith(color: Colors.white),
            children: <TextSpan>[
              TextSpan(
                  text: user.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (departureTime.isNotEmpty)
                TextSpan(
                    text: ' (Salió a las $departureTime)',
                    style: TextStyle(color: Colors.grey[400])),
            ],
          ),
        );
      },
    );
  }
}
