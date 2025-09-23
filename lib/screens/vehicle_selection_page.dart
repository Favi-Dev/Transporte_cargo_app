// Bloque 1: Importaciones
/// Importa todos los paquetes, modelos, pantallas y widgets necesarios.
/// - `material.dart`, `cloud_firestore.dart`, `intl.dart`: Paquetes base de Flutter y Firebase.
/// - `confirmation_page.dart`: La siguiente pantalla en el flujo de asignación.
/// - `curved_background_scaffold.dart`: Para la estética de la app.
/// - `color_utils.dart`: La función auxiliar para las burbujas de color.
/// - `vehicle_model.dart`: Para estructurar los datos de los vehículos.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'confirmation_page.dart';
import '../widgets/curved_background_scaffold.dart';
import '../utils/color_utils.dart';
import 'package:intl/intl.dart';
import '../models/vehicle_model.dart';

// Bloque 2: Definición del StatefulWidget
/// Define la `VehicleSelectionPage` como un `StatefulWidget`. Necesita manejar
/// un estado complejo: qué vehículo está seleccionado, si se está buscando un semi,
/// el texto de búsqueda y los filtros aplicados por el usuario.
class VehicleSelectionPage extends StatefulWidget {
  final String role;
  const VehicleSelectionPage({Key? key, required this.role}) : super(key: key);

  @override
  _VehicleSelectionPageState createState() => _VehicleSelectionPageState();
}

// Bloque 3: Clase de Estado
/// Clase que maneja la lógica y el estado de la pantalla `VehicleSelectionPage`.
class _VehicleSelectionPageState extends State<VehicleSelectionPage> {
  // Bloque 3.1: Variables de Estado
  /// Declara todas las variables de estado que la pantalla necesita "recordar".
  /// - `_selected...Id`: Almacenan las patentes del tracto y semi seleccionados.
  /// - `_isSelectingSemi`: Una bandera booleana que cambia la UI para mostrar la lista de semis.
  /// - `_searchQuery` y `_selectedTypeFilter`: Almacenan los valores de los filtros de la UI.
  String? _selectedTractoId;
  String? _selectedSemiId;
  bool _isSelectingSemi = false;
  String? _selectedTypeFilter;
  String _searchQuery = '';

  // Bloque 3.2: Métodos de Lógica de UI
  /// Conjunto de métodos que se activan por interacciones del usuario.
  /// - `_onTractoSelected`: Se llama al tocar un tracto/camión. Guarda la selección y,
  ///   si es un tracto, muestra el diálogo para preguntar por el semi.
  /// - `_onSemiSelected`: Se llama al tocar un semi y guarda la selección.
  /// - `_goToConfirmation`: Navega a la pantalla de resumen final (`ConfirmationPage`).
  void _onTractoSelected(String tractoId) {
    setState(() {
      _selectedTractoId = tractoId;
    });
    // Solo preguntar por semi si el vehículo es un tracto camión
    FirebaseFirestore.instance
        .collection('vehicles')
        .doc(tractoId)
        .get()
        .then((doc) {
      if (doc.exists && doc.data()?['type'] == 'tracto_camion') {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("¿Deseas agregar un semi remolque?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("No, solo el tracto")),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isSelectingSemi = true;
                  });
                },
                child: const Text("Sí"),
              ),
            ],
          ),
        );
      }
    });
  }

  void _onSemiSelected(String semiId) {
    setState(() {
      _selectedSemiId = semiId;
    });
  }

  void _goToConfirmation() {
    if (_selectedTractoId != null) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmationPage(
                vehicleId: _selectedTractoId!, semiId: _selectedSemiId),
          ));
    }
  }

  // Bloque 4: Método build
  /// Método principal que construye toda la interfaz de la pantalla de selección.
  /// - La `AppBar` es dinámica y cambia su título y botón de retroceso según si se está
  ///   seleccionando un tracto o un semi.
  /// - El cuerpo (`body`) es un `Column` que contiene:
  ///   - `ListTile`s de resumen que muestran las selecciones actuales.
  ///   - La sección de UI para los filtros (búsqueda y menú desplegable).
  ///   - El widget `_VehicleList`, que es el encargado de mostrar la lista de vehículos.
  ///   - El botón final para "Ver Resumen y Confirmar".
  @override
  Widget build(BuildContext context) {
    return CurvedBackgroundScaffold(
      appBar: AppBar(
        title: Text(_isSelectingSemi
            ? "Selecciona un Semi"
            : "Selecciona un Tracto/Camión"),
        leading: _isSelectingSemi
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _isSelectingSemi = false;
                  _selectedTypeFilter =
                      null; // Limpiar filtro al cambiar de modo
                }),
              )
            : null,
      ),
      body: Column(
        children: [
          if (_selectedTractoId != null)
            ListTile(
              title: Text("Tracto seleccionado: $_selectedTractoId"),
              leading: const Icon(Icons.check_circle, color: Colors.green),
              trailing: _isSelectingSemi
                  ? TextButton(
                      child: const Text("CAMBIAR"),
                      onPressed: () => setState(() => _isSelectingSemi = false),
                    )
                  : null,
            ),
          if (_selectedSemiId != null)
            ListTile(
              title: Text("Semi seleccionado: $_selectedSemiId"),
              leading: const Icon(Icons.check_circle, color: Colors.green),
              trailing: TextButton(
                child: const Text("CAMBIAR"),
                onPressed: () => setState(() => _isSelectingSemi = true),
              ),
            ),
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
                          _selectedTypeFilter = value == 'todos' ? null : value;
                        });
                      },
                      itemBuilder: (context) {
                        var items = <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                              value: 'todos', child: Text('Todos los tipos')),
                          const PopupMenuDivider(),
                        ];
                        if (_isSelectingSemi) {
                          items.add(const PopupMenuItem<String>(
                              value: 'semi_remolque',
                              child: Text('Semi Remolque')));
                        } else {
                          items.add(const PopupMenuItem<String>(
                              value: 'tracto_camion',
                              child: Text('Tracto Camión')));
                          items.add(const PopupMenuItem<String>(
                              value: 'camion', child: Text('Camión')));
                        }
                        return items;
                      },
                      icon: const Icon(Icons.filter_list),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.toLowerCase()),
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
          Expanded(
            child: _VehicleList(
              mode: _isSelectingSemi ? 'semi_remolque' : 'tracto_camion',
              ownerFilter: widget.role == 'interno' ? 'fernandez spa' : null,
              onSelect: _isSelectingSemi ? _onSemiSelected : _onTractoSelected,
              selectedId:
                  _isSelectingSemi ? _selectedSemiId : _selectedTractoId,
              searchQuery: _searchQuery,
              typeFilter: _selectedTypeFilter,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _selectedTractoId != null ? _goToConfirmation : null,
              child: const Text("Ver Resumen y Confirmar"),
            ),
          )
        ],
      ),
    );
  }
}

// Bloque 5: Widget _VehicleList
/// Widget auxiliar y privado, diseñado para ser reutilizable dentro de esta pantalla.
/// Su única responsabilidad es mostrar la lista de vehículos. Es un `StatelessWidget`
/// porque recibe toda la información que necesita (como los filtros) desde su widget padre.
class _VehicleList extends StatelessWidget {
  final String mode;
  final String? ownerFilter;
  final Function(String) onSelect;
  final String? selectedId;
  final String searchQuery;
  final String? typeFilter;

  const _VehicleList({
    Key? key,
    required this.mode,
    this.ownerFilter,
    required this.onSelect,
    this.selectedId,
    required this.searchQuery,
    this.typeFilter,
  }) : super(key: key);

  /// Bloque 5.1: Método build de _VehicleList
  /// Construye la lista de vehículos.
  /// - Usa un `StreamBuilder` para conectarse a Firestore y recibir la lista en tiempo real.
  /// - La consulta a Firestore es simple para evitar errores de índices.
  /// - **Toda la lógica de filtrado** (por rol de chofer, por tipo de vehículo y por búsqueda de patente)
  ///   se realiza en el código de la app, después de recibir los datos, para máxima robustez.
  /// - Finalmente, construye un `ListView.builder` con las tarjetas de los vehículos ya filtrados.
  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('vehicles')
        .where('status', isEqualTo: 'disponible');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('Error en el StreamBuilder: ${snapshot.error}');
          return const Center(
            child: Text(
              "Ocurrió un error al cargar los vehículos",
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          debugPrint('No se encontraron vehículos en la consulta.');
          return const Center(
            child: Text(
              "No se encontraron vehículos",
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        var allDocs = snapshot.data!.docs;

        var ownerFilteredDocs = ownerFilter != null
            ? allDocs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return data['owner'] == ownerFilter;
              }).toList()
            : allDocs;

        var vehicles = snapshot.data!.docs
            .map((doc) {
              try {
                var data = doc.data() as Map<String, dynamic>;
                return VehicleModel.fromFirestore(doc);
              } catch (e) {
                debugPrint('Error al convertir documento: $e');
                return null;
              }
            })
            .where((v) => v != null)
            .cast<VehicleModel>()
            .toList();

        if (vehicles.isEmpty) {
          debugPrint(
              'No se encontraron vehículos después de aplicar los filtros.');
          return const Center(
            child: Text(
              "No se encontraron vehículos",
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        var finalFilteredList = vehicles;

        final defaultTypes = mode == 'semi_remolque'
            ? ['semi_remolque']
            : ['tracto_camion', 'camion'];
        finalFilteredList = finalFilteredList
            .where((v) => defaultTypes.contains(v.type))
            .toList();

        if (typeFilter != null) {
          finalFilteredList =
              finalFilteredList.where((v) => v.type == typeFilter).toList();
        }

        if (searchQuery.isNotEmpty) {
          finalFilteredList = finalFilteredList
              .where((v) => v.id.toLowerCase().contains(searchQuery))
              .toList();
        }

        if (finalFilteredList.isEmpty) {
          debugPrint(
              'No se encontraron vehículos después de aplicar los filtros finales.');
          return const Center(
            child: Text(
              "No se encontraron vehículos",
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          itemCount: finalFilteredList.length,
          itemBuilder: (context, index) {
            final vehicle = finalFilteredList[index];
            final isSelected = vehicle.id == selectedId;
            final String colorName =
                vehicle.color.isNotEmpty ? vehicle.color : 'gris';

            return Card(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                  : null,
              child: ListTile(
                leading: Icon(
                  vehicle.type == 'semi_remolque'
                      ? Icons.rv_hookup
                      : Icons.local_shipping,
                  size: 40,
                  color: Colors.white70,
                ),
                title: Text(
                  vehicle.id.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${toBeginningOfSentenceCase(vehicle.brand)} ${toBeginningOfSentenceCase(vehicle.model)} (${vehicle.year})',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: getColorFromString(colorName),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54, width: 1.5),
                  ),
                ),
                onTap: () => onSelect(vehicle.id),
              ),
            );
          },
        );
      },
    );
  }
}
