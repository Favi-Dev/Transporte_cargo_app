// lib/widgets/assigned_driver_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/trip_model.dart';
import '../services/firestore_service.dart';

class AssignedDriverCard extends StatelessWidget {
  final String driverUid;
  final List<VehicleModel> assignedVehicles;

  const AssignedDriverCard({
    Key? key,
    required this.driverUid,
    required this.assignedVehicles,
  }) : super(key: key);

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
                        isLoading ? null : () => Navigator.of(context).pop()),
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No registrada';
    final dt = timestamp.toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final VehicleModel? tracto = assignedVehicles
        .where((v) => v.type == 'tracto_camion' || v.type == 'camion')
        .firstOrNull;
    final VehicleModel? semi =
        assignedVehicles.where((v) => v.type == 'semi_remolque').firstOrNull;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .where('driverId', isEqualTo: driverUid)
            .where('endTime', isEqualTo: null)
            .limit(1)
            .snapshots(),
        builder: (context, tripSnapshot) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(driverUid)
                .get(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData || !tripSnapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Center(child: LinearProgressIndicator()),
                );
              }
              if (!userSnapshot.data!.exists ||
                  userSnapshot.data!.data() == null) {
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

              TripModel? activeTrip;
              if (tripSnapshot.data!.docs.isNotEmpty) {
                activeTrip =
                    TripModel.fromFirestore(tripSnapshot.data!.docs.first);
              }

              return InkWell(
                onTap: () => _showConfirmationDialog(context, user.name),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person,
                              color: Colors.white70, size: 24),
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
                      if (activeTrip?.firstOutput != null &&
                          activeTrip!.firstOutput!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.publish,
                                color: Colors.white70),
                            title: Text(
                              activeTrip.firstOutput!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      if (tracto != null)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.local_shipping,
                              color: Colors.white70),
                          title: Text(
                            tracto.id.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${toBeginningOfSentenceCase(tracto.brand)} ${toBeginningOfSentenceCase(tracto.model)} (${tracto.year})',
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ),
                      if (semi != null)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.rv_hookup,
                              color: Colors.white70),
                          title: Text(
                            semi.id.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
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
          );
        },
      ),
    );
  }
}

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