// Bloque 1: Importaciones
/// Importa todos los paquetes, modelos, pantallas y widgets necesarios para
/// la construcción de la pantalla principal.
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

// Bloque 2: Definición del StatefulWidget
/// Define la `HomePage`, que actúa como la pantalla principal para los usuarios
/// después de iniciar sesión. Es un `StatefulWidget` para poder manejar
/// la lógica de negocio y las actualizaciones de la UI en tiempo real a través de Streams.
/// Recibe el `UserModel` del usuario logueado para personalizar la experiencia.
class HomePage extends StatefulWidget {
  final UserModel user;

  const HomePage({Key? key, required this.user}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

// Bloque 3: Clase de Estado
/// Clase que maneja el estado, la lógica y la interfaz de `HomePage`.
class _HomePageState extends State<HomePage> {
  // Bloque 3.1: Variables de Estado
  /// Declara las variables de estado.
  /// - `_assignedVehiclesStream`: Un stream que escucha en tiempo real si el chofer
  ///   actual tiene vehículos asignados en la colección 'vehicles'.
  /// - `_firestoreService`: Instancia del servicio para la lógica de negocio.
  /// - `_isLoading`: Controla el estado de carga del botón 'Finalizar Ruta'.
  Stream<QuerySnapshot>? _assignedVehiclesStream;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  // Bloque 3.2: Método initState
  /// Método del ciclo de vida que se ejecuta una sola vez al crear la pantalla.
  /// Su función es inicializar el `_assignedVehiclesStream`, configurándolo para
  /// que solo traiga los vehículos cuyo campo `assigned_to` coincida con el UID
  /// del usuario actual.
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      _assignedVehiclesStream = FirebaseFirestore.instance
          .collection('vehicles')
          .where('assigned_to', isEqualTo: uid)
          .snapshots();
    }
  }

  // Bloque 3.3: Método _handleReleaseVehicle
  /// Método asíncrono que gestiona la finalización de un viaje por parte del chofer.
  /// Llama al método `releaseVehiclesFromDriver` del servicio, que actualiza la
  /// base de datos (libera vehículos, crea el registro del viaje, etc.)
  /// y muestra un `SnackBar` de éxito o error al finalizar.
  Future<void> _handleReleaseVehicle() async {
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
        // Elimina la línea de navegación, ya que la UI se actualizará sola.
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al finalizar ruta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Bloque 4: Método build
  /// Método principal que construye la interfaz de usuario de la pantalla.
  /// Su lógica es altamente condicional, actuando como un enrutador.
  @override
  Widget build(BuildContext context) {
    // La condición debe incluir al super_admin
    if (widget.user.role == 'admin' || widget.user.role == 'super_admin') {
      // --- CAMBIO AQUÍ: Pasamos el modelo del admin al dashboard ---
      return AdminDashboardScreen(adminUser: widget.user);
    }

    if (widget.user.onRoute) {
      return StreamBuilder<QuerySnapshot>(
        stream: _assignedVehiclesStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildNoTripView(context);
          }
          return _buildOnTripView(context, snapshot.data!.docs);
        },
      );
    } else {
      return _buildNoTripView(context);
    }
  }

  /// Bloque 4.2: Vista del Chofer
  /// Si el usuario no es admin, construye la vista del chofer usando el `CurvedBackgroundScaffold`
  /// y un `StreamBuilder` para reaccionar a los cambios en su estado de asignación.
  CurvedBackgroundScaffold _buildNoTripView(BuildContext context) {
    return CurvedBackgroundScaffold(
      appBar: AppBar(title: Text("Bienvenido ${widget.user.name}")),
      body: Center(
        child: StreamBuilder<QuerySnapshot>(
          stream: _assignedVehiclesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            /// Bloque 4.2.1: Vista "Sin Viaje"
            /// Si el stream no tiene datos o la lista de vehículos asignados está vacía,
            /// construye la 'tarjeta de bienvenida', invitando al chofer a seleccionar
            /// un vehículo para iniciar una nueva ruta.
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 40.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.key_outlined,
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
                                builder: (context) => VehicleSelectionPage(
                                    role: widget.user.role),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            /// Bloque 4.2.2: Vista "En Ruta"
            /// Si el stream trae vehículos asignados, construye la tarjeta de 'Viaje en Curso'.
            /// Procesa los datos para identificar el tracto y el semi, formatea la hora de salida
            /// y muestra toda la información de forma detallada usando `ListTile`s.
            VehicleModel? vehicle;
            VehicleModel? semi;
            for (var doc in snapshot.data!.docs) {
              final vehicleModel = VehicleModel.fromFirestore(doc);
              if (vehicleModel.type == 'semi_remolque') {
                semi = vehicleModel;
              } else {
                vehicle = vehicleModel;
              }
            }

            final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
            final departureTime = widget.user.departureTime != null
                ? dateFormat.format(widget.user.departureTime!.toDate())
                : 'No registrada';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping,
                    size: 60,
                    color: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.color
                        ?.withOpacity(0.8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Viaje en Curso',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          if (vehicle != null)
                            ListTile(
                              leading: const Icon(Icons.local_shipping,
                                  color: Colors.white70),
                              title: Text(vehicle.id.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  '${vehicle.brand} ${vehicle.model} (${vehicle.year})',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                            ),
                          if (semi != null)
                            ListTile(
                              leading: const Icon(Icons.rv_hookup,
                                  color: Colors.white70),
                              title: Text(semi.id.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  '${semi.brand} ${semi.model} (${semi.year})',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                            ),
                          const Divider(
                              color: Colors.white24, indent: 16, endIndent: 16),
                          ListTile(
                            leading: const Icon(Icons.timer_outlined,
                                color: Colors.white70),
                            title: const Text('Hora de Salida',
                                style: TextStyle(color: Colors.white)),
                            subtitle: Text(departureTime,
                                style: const TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleReleaseVehicle,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Finalizar Ruta"),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOnTripView(BuildContext context, List<DocumentSnapshot> docs) {
    VehicleModel? vehicle;
    VehicleModel? semi;
    for (var doc in docs) {
      final vehicleModel = VehicleModel.fromFirestore(doc);
      if (vehicleModel.type == 'semi_remolque') {
        semi = vehicleModel;
      } else {
        vehicle = vehicleModel;
      }
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final departureTime = widget.user.departureTime != null
        ? dateFormat.format(widget.user.departureTime!.toDate())
        : 'No registrada';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping,
            size: 60,
            color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8),
          ),
          const SizedBox(height: 8),
          Text(
            'Viaje en Curso',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  if (vehicle != null)
                    ListTile(
                      leading: const Icon(Icons.local_shipping, color: Colors.white70),
                      title: Text(vehicle.id.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${vehicle.brand} ${vehicle.model} (${vehicle.year})',
                          style: const TextStyle(color: Colors.white70)),
                    ),
                  if (semi != null)
                    ListTile(
                      leading: const Icon(Icons.rv_hookup, color: Colors.white70),
                      title: Text(semi.id.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${semi.brand} ${semi.model} (${semi.year})',
                          style: const TextStyle(color: Colors.white70)),
                    ),
                  const Divider(color: Colors.white24, indent: 16, endIndent: 16),
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
          ElevatedButton(
            onPressed: _isLoading ? null : _handleReleaseVehicle,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Finalizar Ruta"),
          ),
        ],
      ),
    );
  }
}
