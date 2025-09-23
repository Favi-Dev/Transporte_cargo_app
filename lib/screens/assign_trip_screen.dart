import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../services/firestore_service.dart';
import '../widgets/curved_background_scaffold.dart';

/// Bloque 1: Enum de Pasos
/// Define un enumerador (`Enum`) para controlar los pasos del proceso de asignación.
/// Esto hace el código más legible y mantenible que usar números o strings.
enum AssignStep { selectDriver, selectVehicle }

/// Bloque 2: Definición del StatefulWidget
/// Define la pantalla `AssignTripScreen` como un `StatefulWidget`, ya que su
/// contenido y estado cambian a medida que el administrador avanza en el proceso
/// de selección de chofer y vehículos.
class AssignTripScreen extends StatefulWidget {
  const AssignTripScreen({Key? key}) : super(key: key);

  @override
  _AssignTripScreenState createState() => _AssignTripScreenState();
}

/// Bloque 3: Clase de Estado
/// Clase que maneja toda la lógica y el estado de la pantalla de asignación.
class _AssignTripScreenState extends State<AssignTripScreen> {
  /// Bloque 3.1: Variables de Estado
  /// Declara todas las variables que la pantalla necesita "recordar" a lo largo
  /// de su ciclo de vida.
  /// - `_firestoreService`: Instancia para la comunicación con la base de datos.
  /// - `_currentStep`: Controla en qué paso del asistente nos encontramos.
  /// - `_selected...`: Almacenan las selecciones (chofer, tracto, semi) que el admin va haciendo.
  /// - `_is...`: Banderas booleanas para estados secundarios, como el modo de selección de semi.
  /// - Variables de filtro y búsqueda para las listas de choferes y vehículos.
  final FirestoreService _firestoreService = FirestoreService();

  AssignStep _currentStep = AssignStep.selectDriver;
  UserModel? _selectedDriver;
  VehicleModel? _selectedTracto;
  VehicleModel? _selectedSemi;
  bool _isSelectingSemi = false;
  bool _isLoading = false;

  String? _selectedRoleFilter;
  String _searchDriverQuery = '';
  String? _selectedVehicleTypeFilter;
  String _searchVehicleQuery = '';

  /// Bloque 3.2: Métodos de Lógica de UI
  /// Conjunto de métodos que manejan las interacciones del usuario y actualizan el
  /// estado de la pantalla llamando a `setState`.
  /// - `_onDriverSelected`: Se activa al tocar un chofer. Guarda la selección y avanza al paso de seleccionar vehículo.
  /// - `_onVehicleSelected`: Gestiona la selección del vehículo principal y del semi.
  /// - `_showSemiConfirmationDialog`: Muestra un diálogo para preguntar si se desea añadir un semi.
  /// - `_confirmAssignment`: Contiene la lógica final para llamar al servicio de Firestore y guardar la asignación.
  /// - `_resetVehicleSelection`: Limpia la selección de vehículos si el admin vuelve al paso anterior.
  void _onDriverSelected(UserModel driver) {
    setState(() {
      _selectedDriver = driver;
      _currentStep = AssignStep.selectVehicle;
    });
  }

  void _onVehicleSelected(VehicleModel vehicle) {
    final type = vehicle.type;
    if (type == 'tracto_camion' || type == 'camion') {
      setState(() {
        _selectedTracto = vehicle;
        _selectedSemi = null;
      });
      if (type == 'tracto_camion') {
        _showSemiConfirmationDialog();
      }
    } else if (type == 'semi_remolque') {
      setState(() {
        _selectedSemi = vehicle;
        _isSelectingSemi = false;
      });
    }
  }

  void _showSemiConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Agregar Semi Remolque?"),
        actions: [
          TextButton(
            child: const Text("No, solo el tracto"),
            onPressed: () {
              setState(() => _isSelectingSemi = false);
              Navigator.of(ctx).pop();
            },
          ),
          TextButton(
            child: const Text("Sí, seleccionar"),
            onPressed: () {
              setState(() {
                _isSelectingSemi = true;
              });
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAssignment() async {
    if (_selectedDriver == null || _selectedTracto == null) return;
    setState(() => _isLoading = true);
    try {
      await _firestoreService.assignVehiclesToDriverByAdmin(
        driverUid: _selectedDriver!.uid,
        vehicleId: _selectedTracto!.id,
        semiId: _selectedSemi?.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Viaje asignado con éxito'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al asignar el viaje: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetVehicleSelection() {
    setState(() {
      _selectedTracto = null;
      _selectedSemi = null;
      _isSelectingSemi = false;
    });
  }

  /// Bloque 4: Método build Principal
  /// Construye la estructura base de la pantalla.
  /// - Usa `CurvedBackgroundScaffold` para el diseño visual.
  /// - La `AppBar` es dinámica: su título y el botón de retroceso cambian según el paso actual (`_currentStep`).
  /// - El cuerpo (`body`) es condicional: muestra un `CircularProgressIndicator` si está cargando,
  ///   o llama a los métodos `_buildDriverList` o `_buildVehicleSelection` para construir la
  ///   interfaz correspondiente al paso del asistente en el que se encuentre el admin.
  @override
  Widget build(BuildContext context) {
    return CurvedBackgroundScaffold(
      appBar: AppBar(
        title: Text(_currentStep == AssignStep.selectDriver
            ? '1. Seleccionar Chofer'
            : (_isSelectingSemi
                ? 'Seleccionar Semi'
                : '2. Seleccionar Vehículo')),
        leading: _currentStep == AssignStep.selectVehicle
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _currentStep = AssignStep.selectDriver;
                  _selectedDriver = null;
                  _resetVehicleSelection();
                }),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentStep == AssignStep.selectDriver
              ? _buildDriverList()
              : _buildVehicleSelection(),
    );
  }

  /// Bloque 5: Método _buildDriverList
  /// Widget que construye la primera parte de la interfaz: la lista de choferes.
  /// Contiene los widgets de la UI para los filtros y la búsqueda, y un `StreamBuilder`
  /// que se conecta a la colección `users` para mostrar los choferes disponibles
  /// en tiempo real, aplicando los filtros que el admin haya seleccionado.
  Widget _buildDriverList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filtrar Choferes',
                      style: Theme.of(context).textTheme.titleLarge),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      setState(() {
                        _selectedRoleFilter = value == 'todos' ? null : value;
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'todos', child: Text('Todos')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                          value: 'interno', child: Text('Internos')),
                      const PopupMenuItem(
                          value: 'externo', child: Text('Externos')),
                    ],
                    icon: const Icon(Icons.filter_list),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) =>
                    setState(() => _searchDriverQuery = value.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('on_route', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              var drivers = snapshot.data!.docs
                  .map((doc) => UserModel.fromFirestore(doc))
                  .where((user) => user.role != 'admin')
                  .toList();

              if (_selectedRoleFilter != null) {
                drivers = drivers
                    .where((d) => d.role == _selectedRoleFilter)
                    .toList();
              }
              if (_searchDriverQuery.isNotEmpty) {
                drivers = drivers
                    .where((d) =>
                        d.name.toLowerCase().contains(_searchDriverQuery))
                    .toList();
              }

              if (drivers.isEmpty)
                return const Center(
                    child: Text('No hay choferes disponibles.'));

              return ListView.builder(
                itemCount: drivers.length,
                itemBuilder: (context, index) {
                  final user = drivers[index];
                  return Card(
                    child: ListTile(
                      title: Text(user.name,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(user.rut,
                          style: const TextStyle(color: Colors.white70)),
                      trailing: Chip(
                        label: Text(
                            user.role[0].toUpperCase() + user.role.substring(1),
                            style: const TextStyle(color: Colors.white)),
                        backgroundColor:
                            user.role == 'interno' ? Colors.green : Colors.blue,
                      ),
                      leading: const Icon(Icons.person, color: Colors.white70),
                      onTap: () => _onDriverSelected(user),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Bloque 6: Método _buildVehicleSelection
  /// Widget que construye la segunda parte de la interfaz: la selección de vehículos.
  /// Contiene una tarjeta de resumen con el chofer ya seleccionado, la UI de filtros
  /// para vehículos, y un `StreamBuilder` que se conecta a la colección `vehicles` para
  /// mostrar los vehículos disponibles. Crucialmente, aplica un filtro basado en el
  /// rol del chofer seleccionado para asegurar que solo se muestren vehículos válidos.
  Widget _buildVehicleSelection() {
    final vehicleTypesToShow =
        _isSelectingSemi ? ['semi_remolque'] : ['tracto_camion', 'camion'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filtrar Vehículos',
                      style: Theme.of(context).textTheme.titleLarge),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      setState(() {
                        _selectedVehicleTypeFilter =
                            value == 'todos' ? null : value;
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'todos', child: Text('Todos')),
                      if (!_isSelectingSemi) ...[
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                            value: 'tracto_camion',
                            child: Text('Tracto Camión')),
                        const PopupMenuItem(
                            value: 'camion', child: Text('Camión')),
                      ] else ...[
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                            value: 'semi_remolque',
                            child: Text('Semi Remolque')),
                      ],
                    ],
                    icon: const Icon(Icons.filter_list),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) =>
                    setState(() => _searchVehicleQuery = value.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar por patente...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
              ),
            ],
          ),
        ),
        Card(
          child: ListTile(
            title: Text('Chofer: ${_selectedDriver!.name}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Tracto: ${_selectedTracto?.id ?? "No seleccionado"}\nSemi: ${_selectedSemi?.id ?? "No seleccionado"}',
                style: const TextStyle(color: Colors.white70)),
            isThreeLine: true,
            trailing: _selectedTracto != null
                ? TextButton(
                    child: const Text('CAMBIAR',
                        style: TextStyle(color: Colors.white)),
                    onPressed: _resetVehicleSelection,
                  )
                : null,
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('vehicles')
                .where('status', isEqualTo: 'disponible')
                .where('type', whereIn: vehicleTypesToShow)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              var vehicles = snapshot.data!.docs
                  .map((doc) => VehicleModel.fromFirestore(doc))
                  .toList();

              if (_selectedDriver?.role == 'interno') {
                vehicles =
                    vehicles.where((v) => v.owner == 'fernandez spa').toList();
              } else if (_selectedDriver?.role == 'externo') {
                vehicles =
                    vehicles.where((v) => v.owner != 'fernandez spa').toList();
              }

              if (_selectedVehicleTypeFilter != null) {
                vehicles = vehicles
                    .where((v) => v.type == _selectedVehicleTypeFilter)
                    .toList();
              }
              if (_searchVehicleQuery.isNotEmpty) {
                vehicles = vehicles
                    .where(
                        (v) => v.id.toLowerCase().contains(_searchVehicleQuery))
                    .toList();
              }

              if (vehicles.isEmpty)
                return const Center(
                    child:
                        Text('No hay vehículos disponibles para este chofer.'));

              return ListView.builder(
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];
                  final isSelected = vehicle.id == _selectedTracto?.id ||
                      vehicle.id == _selectedSemi?.id;
                  return Card(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                        : null,
                    child: ListTile(
                      leading: Icon(
                          vehicle.type == 'semi_remolque'
                              ? Icons.rv_hookup
                              : Icons.local_shipping,
                          color: Colors.white70),
                      title: Text(
                        '${toBeginningOfSentenceCase(vehicle.brand) ?? vehicle.brand} ${toBeginningOfSentenceCase(vehicle.model) ?? vehicle.model}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Patente: ${vehicle.id.toUpperCase()} | Color: ${toBeginningOfSentenceCase(vehicle.color) ?? vehicle.color}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      onTap: () => _onVehicleSelected(vehicle),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              side: const BorderSide(color: Colors.white, width: 2),
            ),
            onPressed: (_selectedDriver != null &&
                    _selectedTracto != null &&
                    !_isLoading)
                ? _confirmAssignment
                : null,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Confirmar Asignación'),
          ),
        )
      ],
    );
  }
}
