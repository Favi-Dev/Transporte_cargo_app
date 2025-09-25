// lib/screens/vehicle_selection_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'confirmation_page.dart';
// CAMBIO: Importar el widget renombrado.
import '../widgets/curved_background_scaffold.dart';
import '../utils/color_utils.dart';
import 'package:intl/intl.dart';
import '../models/vehicle_model.dart';

class VehicleSelectionPage extends StatefulWidget {
  final String role;
  const VehicleSelectionPage({Key? key, required this.role}) : super(key: key);

  @override
  _VehicleSelectionPageState createState() => _VehicleSelectionPageState();
}

class _VehicleSelectionPageState extends State<VehicleSelectionPage> {
  String? _selectedTractoId;
  String? _selectedSemiId;
  bool _isSelectingSemi = false;
  String? _selectedTypeFilter;
  String _searchQuery = '';

  void _onTractoSelected(String tractoId) {
    setState(() {
      _selectedTractoId = tractoId;
    });
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

  @override
  Widget build(BuildContext context) {
    // CAMBIO: Se envuelve el contenido en un Scaffold...
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectingSemi
            ? "Selecciona un Semi"
            : "Selecciona un Tracto/Camión"),
        leading: _isSelectingSemi
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _isSelectingSemi = false;
                  _selectedTypeFilter = null;
                }),
              )
            : null,
      ),
      // ...y se usa CurvedBackground en el body.
      body: CurvedBackground(
        child: Column(
          children: [
            if (_selectedTractoId != null)
              ListTile(
                title: Text("Tracto seleccionado: $_selectedTractoId"),
                leading: const Icon(Icons.check_circle, color: Colors.green),
                trailing: _isSelectingSemi
                    ? TextButton(
                        child: const Text("CAMBIAR"),
                        onPressed: () =>
                            setState(() => _isSelectingSemi = false),
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
                            _selectedTypeFilter =
                                value == 'todos' ? null : value;
                          });
                        },
                        itemBuilder: (context) {
                          var items = <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                                value: 'todos',
                                child: Text('Todos los tipos')),
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
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _VehicleList(
                mode: _isSelectingSemi ? 'semi_remolque' : 'tracto_camion',
                  userRole: widget.role,
                onSelect:
                    _isSelectingSemi ? _onSemiSelected : _onTractoSelected,
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
      ),
    );
  }
}

class _VehicleList extends StatelessWidget {
  final String mode;
  final String userRole;
  final Function(String) onSelect;
  final String? selectedId;
  final String searchQuery;
  final String? typeFilter;

  const _VehicleList({
    Key? key,
    required this.mode,
    required this.userRole,
    required this.onSelect,
    this.selectedId,
    required this.searchQuery,
    this.typeFilter,
  }) : super(key: key);

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
          return const Center(
            child: Text(
              "No se encontraron vehículos",
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        var vehicles = snapshot.data!.docs
            .map((doc) => VehicleModel.fromFirestore(doc))
            .toList();

        // Filtro por rol del usuario
        if (userRole == 'interno') {
          vehicles =
              vehicles.where((v) => v.owner.toLowerCase() == 'fernandez spa').toList();
        } else if (userRole == 'externo') {
          vehicles =
              vehicles.where((v) => v.owner.toLowerCase() != 'fernandez spa').toList();
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
          return const Center(
            child: Text(
              "No se encontraron vehículos con estos filtros",
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