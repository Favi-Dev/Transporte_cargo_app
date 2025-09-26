// lib/screens/home_page.dart

import 'package:fernandez_cargo_app/models/trip_model.dart';
import 'package:fernandez_cargo_app/models/vehicle_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'admin_dashboard_screen.dart';
import 'vehicle_selection_page.dart';
import '../widgets/curved_background_scaffold.dart';

class HomePage extends StatefulWidget {
  final UserModel user;
  const HomePage({Key? key, required this.user}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Stream<QuerySnapshot>? _assignedVehiclesStream;
  Stream<QuerySnapshot>? _activeTripStream;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      _assignedVehiclesStream = FirebaseFirestore.instance
          .collection('vehicles')
          .where('assigned_to', isEqualTo: uid)
          .snapshots();

      _activeTripStream = FirebaseFirestore.instance
          .collection('trips')
          .where('driverId', isEqualTo: uid)
          .where('endTime', isEqualTo: null)
          .limit(1)
          .snapshots();
    }
  }

  // ===================================================================
  // Flujo de llegada y finalización de ruta
  // ===================================================================
  Future<void> _handleArrival() async {
    final bool? hasArrived = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Llegada a Destino'),
        content: const Text('¿Has llegado a una parada o destino?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sí')),
        ],
      ),
    );

    if (hasArrived != true) return;

    final arrivalLocationController = TextEditingController();
    final bool? locationConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Registrar Parada'),
          content: TextField(
            controller: arrivalLocationController,
            decoration: const InputDecoration(
              labelText: 'Lugar de llegada (Ej: SLC)',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () async {
                  if (arrivalLocationController.text.trim().isNotEmpty) {
                    setState(() => _isLoading = true);
                    try {
                      await _firestoreService
                          .addStopToTrip(arrivalLocationController.text.trim());
                      Navigator.of(ctx).pop(true);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Error al guardar parada: $e'),
                          backgroundColor: Colors.red));
                      Navigator.of(ctx).pop(false);
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  }
                },
                child: const Text('Guardar Parada')),
          ],
        );
      },
    );

    if (locationConfirmed != true) return;

    final bool? continueRoute = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Continuar Ruta?'),
        content: const Text(
            'La parada ha sido registrada. ¿Deseas continuar hacia otro destino?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No, finalizar')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sí, continuar')),
        ],
      ),
    );

    if (continueRoute == true) {
      return;
    } else {
      _showFinalizeConfirmation();
    }
  }

  void _showFinalizeConfirmation() async {
    final bool? finalize = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Seguro?'),
        content: const Text(
            '¿Estás seguro de que quieres finalizar la ruta por completo?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Finalizar Ruta')),
        ],
      ),
    );

    if (finalize == true) {
      await _finalizeRoute();
    }
  }

  Future<void> _finalizeRoute() async {
    setState(() => _isLoading = true);
    try {
      await _firestoreService.releaseVehiclesFromDriver();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Viaje finalizado con éxito. Ahora puedes seleccionar un nuevo vehículo.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al finalizar ruta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.role == 'admin' || widget.user.role == 'super_admin') {
      return AdminDashboardScreen(adminUser: widget.user);
    }

    if (widget.user.onRoute) {
      return _buildOnTripView(context);
    } else {
      return _buildNoTripView(context);
    }
  }

  Widget _buildNoTripView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bienvenido ${widget.user.name}")),
      body: CurvedBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.key_outlined,
                        size: 60, color: Colors.white70),
                    const SizedBox(height: 20),
                    Text(
                      '¡Listo para la ruta!',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No tienes un vehículo asignado en este momento.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.local_shipping),
                      label: const Text("Seleccionar Vehículo"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                VehicleSelectionPage(role: widget.user.role),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnTripView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viaje en Curso')),
      body: CurvedBackground(
        padBottomByWave: true,
        heightFactor: 0.24,
        child: StreamBuilder<QuerySnapshot>(
          stream: _activeTripStream,
          builder: (context, tripSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: _assignedVehiclesStream,
              builder: (context, vehicleSnapshot) {
                if (vehicleSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    tripSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!vehicleSnapshot.hasData ||
                    vehicleSnapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("Actualizando estado..."),
                    ),
                  );
                }

                VehicleModel? vehicle;
                VehicleModel? semi;
                for (var doc in vehicleSnapshot.data!.docs) {
                  final vehicleModel = VehicleModel.fromFirestore(doc);
                  if (vehicleModel.type == 'semi_remolque') {
                    semi = vehicleModel;
                  } else {
                    vehicle = vehicleModel;
                  }
                }

                TripModel? activeTrip;
                if (tripSnapshot.hasData &&
                    tripSnapshot.data!.docs.isNotEmpty) {
                  activeTrip =
                      TripModel.fromFirestore(tripSnapshot.data!.docs.first);
                }

                final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
                final departureTime = widget.user.departureTime != null
                    ? dateFormat.format(widget.user.departureTime!.toDate())
                    : 'No registrada';

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_shipping,
                                  size: 60,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color
                                      ?.withOpacity(0.8)),
                              const SizedBox(height: 8),
                              Text('Detalles del Viaje',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const SizedBox(height: 24),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    children: [
                                      if (vehicle != null)
                                        ListTile(
                                            leading: const Icon(
                                                Icons.local_shipping,
                                                color: Colors.white70),
                                            title: Text(
                                                vehicle.id.toUpperCase(),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            subtitle: Text(
                                                '${vehicle.brand} ${vehicle.model} (${vehicle.year})',
                                                style: const TextStyle(
                                                    color: Colors.white70))),
                                      if (semi != null)
                                        ListTile(
                                            leading: const Icon(
                                                Icons.rv_hookup,
                                                color: Colors.white70),
                                            title: Text(semi.id.toUpperCase(),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            subtitle: Text(
                                                '${semi.brand} ${semi.model} (${semi.year})',
                                                style: const TextStyle(
                                                    color: Colors.white70))),
                                      const Divider(
                                          color: Colors.white24,
                                          indent: 16,
                                          endIndent: 16),
                                      // ==========================================================
                                      // CORRECCIÓN: Se leen los datos del historial de paradas
                                      // ==========================================================
                                      if (activeTrip != null &&
                                          activeTrip.stops.isNotEmpty)
                                        ...activeTrip.stops.map((stop) {
                                          final location = stop['location'] ?? 'Parada no registrada';
                                          final timestamp = stop['timestamp'] as Timestamp?;
                                          final time = timestamp != null
                                              ? DateFormat('dd/MM HH:mm').format(timestamp.toDate())
                                              : 'Hora no registrada';

                                          return ListTile(
                                            leading: const Icon(Icons.location_on, color: Colors.white70),
                                            title: Text(location, style: const TextStyle(color: Colors.white)),
                                            subtitle: Text(time, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                          );
                                        }).toList(),
                                      // Mantén la hora de salida si deseas mostrarla:
                                      ListTile(
                                        leading: const Icon(Icons.timer_outlined, color: Colors.white70),
                                        title: const Text('Hora de Salida', style: TextStyle(color: Colors.white)),
                                        subtitle: Text(departureTime, style: const TextStyle(color: Colors.white70)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              // Botón para registrar llegada o finalizar
                              ElevatedButton(
                                onPressed: _isLoading ? null : _handleArrival,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Text("Llegada a Destino"),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}