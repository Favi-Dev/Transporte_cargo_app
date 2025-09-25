// Bloque 1: Importaciones
/// Importaciones necesarias para la vista de vehículos disponibles.
/// - `material.dart`: Widgets de Flutter.
/// - `cloud_firestore.dart`: Para conectarse a la base de datos Firestore.
/// - `intl.dart`: Aunque no se usa directamente aquí, a menudo es útil para formateo.
/// - `vehicle_model.dart`: Para convertir los datos de Firestore en objetos VehicleModel.
/// - `vehicle_status_card.dart`: El widget reutilizable para mostrar cada vehículo.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/vehicle_model.dart';
import '../vehicle_status_card.dart';

// Bloque 2: Definición del StatefulWidget
/// Define la vista `AvailableVehiclesView` como un `StatefulWidget`.
/// Necesita tener estado para poder gestionar los filtros de búsqueda y tipo
/// que el administrador puede aplicar, y redibujar la lista cuando estos cambian.
class AvailableVehiclesView extends StatefulWidget {
  const AvailableVehiclesView({Key? key}) : super(key: key);

  @override
  State<AvailableVehiclesView> createState() => _AvailableVehiclesViewState();
}

// Bloque 3: Clase de Estado
/// Clase que maneja el estado y la lógica de la vista `AvailableVehiclesView`.
class _AvailableVehiclesViewState extends State<AvailableVehiclesView> {
  /// Bloque 3.1: Variables de Estado
  /// Declara las variables de estado que almacenarán los valores actuales de los filtros.
  /// - `_searchQuery`: Guarda el texto que el administrador escribe en el campo de búsqueda.
  /// - `_selectedTypeFilter`: Guarda el tipo de vehículo seleccionado en el menú de filtro.
  String _searchQuery = '';
  String? _selectedTypeFilter;

  /// Bloque 4: Método build
  /// Método principal que construye la interfaz de usuario de esta pestaña.
  /// Se divide en dos partes principales: la sección de filtros y la lista de vehículos.
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// Bloque 4.1: Sección de UI para los Filtros
        /// Contiene un `Row` con un título y un `PopupMenuButton` para filtrar por
        /// tipo de vehículo, y un `TextField` para buscar por patente. Las interacciones
        /// del usuario (`onChanged`, `onSelected`) actualizan las variables de estado y
        /// redibujan la pantalla gracias a `setState`.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filtrar Flota',
                      style: Theme.of(context).textTheme.titleLarge),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      setState(() {
                        _selectedTypeFilter = (value == 'todos') ? null : value;
                      });
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                          value: 'todos', child: Text('Todos los tipos')),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                          value: 'tracto_camion', child: Text('Tracto Camión')),
                      const PopupMenuItem<String>(
                          value: 'semi_remolque', child: Text('Semi Remolque')),
                      const PopupMenuItem<String>(
                          value: 'camion', child: Text('Camión')),
                    ],
                    icon: const Icon(Icons.filter_list),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
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

        /// Bloque 4.2: Sección de la Lista de Vehículos
        /// Un `Expanded` asegura que la lista ocupe todo el espacio restante.
        /// Dentro, un `StreamBuilder` se conecta a Firestore para obtener en tiempo
        /// real solo los vehículos con `status: 'disponible'`.
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('vehicles')
                .where('status', isEqualTo: 'disponible')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Ocurrió un error.'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text('No hay vehículos disponibles.',
                        style: TextStyle(fontSize: 16, color: Colors.grey)));
              }

              /// Bloque 4.2.1: Lógica de Filtrado en la App
              /// Después de recibir los datos, se aplica una segunda capa de filtrado
              /// en la app usando las variables de estado `_selectedTypeFilter` y `_searchQuery`.
              /// Esto permite un filtrado dinámico sin necesidad de hacer nuevas consultas
              /// complejas a Firestore.
              var availableVehicles = snapshot.data!.docs
                  .where((doc) => doc.data() != null)
                  .map((doc) => VehicleModel.fromFirestore(doc))
                  .toList();

              if (_selectedTypeFilter != null) {
                availableVehicles = availableVehicles
                    .where((v) => v.type == _selectedTypeFilter)
                    .toList();
              }
              if (_searchQuery.isNotEmpty) {
                availableVehicles = availableVehicles
                    .where((v) =>
                        v.id.toLowerCase().contains(_searchQuery.toLowerCase()))
                    .toList();
              }

              if (availableVehicles.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                      child: Text(
                          'No se encontraron vehículos con esos filtros.',
                          textAlign: TextAlign.center)),
                );
              }

              /// Bloque 4.2.2: Construcción de la Lista
              /// Muestra la lista final ya filtrada usando `ListView.builder` para un
              /// rendimiento óptimo, y el widget reutilizable `VehicleStatusCard` para cada ítem.
              return ListView.builder(
                padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                itemCount: availableVehicles.length,
                itemBuilder: (context, index) {
                  return VehicleStatusCard(vehicle: availableVehicles[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
