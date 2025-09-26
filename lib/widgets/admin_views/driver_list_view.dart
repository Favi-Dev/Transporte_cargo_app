// Bloque 1: Importaciones
/// Importaciones necesarias para la vista.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../screens/profile_screen.dart';
import '../../services/firestore_service.dart';
import '../../screens/driver_form_screen.dart';

// Bloque 2: Definición del StatefulWidget
/// Define `DriverListView` como un `StatefulWidget`. Necesita estado para
/// gestionar los filtros de búsqueda y rol que el admin aplica.
class DriverListView extends StatefulWidget {
  /// Recibe el `UserModel` del admin que está viendo la pantalla.
  /// Es crucial para la lógica de permisos (ej. mostrar el botón de desactivar).
  final UserModel adminUser;
  const DriverListView({Key? key, required this.adminUser}) : super(key: key);

  @override
  State<DriverListView> createState() => _DriverListViewState();
}

// Bloque 3: Clase de Estado
/// Clase que maneja el estado y la lógica de la `DriverListView`.
class _DriverListViewState extends State<DriverListView> {
  String _searchQuery = '';
  String? _activeFilter;

  /// Diálogo de confirmación de ELIMINACIÓN permanente
  void _showDeleteConfirmationDialog(
      BuildContext context, UserModel userToDelete) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
            '¿Estás seguro de que quieres ELIMINAR PERMANENTEMENTE a ${userToDelete.name}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
            onPressed: () async {
              try {
                await FirestoreService().deleteDriver(userToDelete.uid);
                Navigator.of(ctx).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Chofer eliminado con éxito.'),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                Navigator.of(ctx).pop();
                if (!mounted) return;
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

  /// Bloque 4: Método build
  /// Construye la interfaz de la pestaña, dividida en la sección de filtros y la lista.
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// Bloque 4.1: UI de Filtros
        /// Contiene el `PopupMenuButton` y el `TextField` que permiten al
        /// admin filtrar y buscar en la lista de choferes.
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
                        _activeFilter = (value == 'todos') ? null : value;
                      });
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                          value: 'todos', child: Text('Mostrar Todos')),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                          value: 'disponible', child: Text('Disponibles')),
                      const PopupMenuItem<String>(
                          value: 'en_ruta', child: Text('En Ruta')),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                          value: 'interno', child: Text('Internos')),
                      const PopupMenuItem<String>(
                          value: 'externo', child: Text('Externos')),
                    ],
                    icon: const Icon(Icons.filter_list),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o RUT...',
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

        /// Bloque 4.2: Lista de Choferes
        /// `StreamBuilder` se conecta a la colección `users` para obtener los datos
        /// en tiempo real, excluyendo a los usuarios desactivados.
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('role',
                whereIn: [
                  'interno',
                  'externo',
                  'admin',
                  'super_admin'
                ]).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Ocurrió un error.'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text('No hay choferes registrados.'));
              }

              var allUsers = snapshot.data!.docs
                  .map((doc) => UserModel.fromFirestore(doc))
                  .toList();

              // --- 3. FILTRO PARA OCULTAR ADMINS A OTROS ADMINS ---
              // Un admin normal solo verá a los choferes.
              // Un super_admin los verá a todos (excepto a sí mismo).
              var visibleUsers = allUsers.where((user) {
                if (widget.adminUser.role == 'admin') {
                  // Si soy admin, solo quiero ver roles de chofer
                  return user.role == 'interno' || user.role == 'externo';
                }
                // Si soy super_admin, los veo a todos
                return true;
              }).toList();

              // Filtramos al propio admin para que no se vea a sí mismo en la lista
              visibleUsers = visibleUsers
                  .where((user) => user.uid != widget.adminUser.uid)
                  .toList();

              var drivers = visibleUsers;

              /// Bloque 4.2.1: Lógica de Filtrado
              /// Aplica los filtros de búsqueda y de menú a la lista de choferes.
              if (_searchQuery.isNotEmpty) {
                drivers = drivers.where((driver) {
                  return driver.name.toLowerCase().contains(_searchQuery) ||
                      driver.rut.toLowerCase().contains(_searchQuery);
                }).toList();
              }
              if (_activeFilter != null) {
                switch (_activeFilter) {
                  case 'disponible':
                    drivers =
                        drivers.where((driver) => !driver.onRoute).toList();
                    break;
                  case 'en_ruta':
                    drivers =
                        drivers.where((driver) => driver.onRoute).toList();
                    break;
                  case 'interno':
                    drivers = drivers
                        .where((driver) => driver.role == 'interno')
                        .toList();
                    break;
                  case 'externo':
                    drivers = drivers
                        .where((driver) => driver.role == 'externo')
                        .toList();
                    break;
                }
              }

              if (drivers.isEmpty) {
                return const Center(
                    child:
                        Text('No se encontraron choferes con esos filtros.'));
              }

              /// Bloque 4.2.2: Construcción de la Lista
              /// Muestra la lista final filtrada. Cada `ListTile` es interactivo (`onTap`)
              /// y muestra botones de acción (`trailing`) basados en los permisos del admin.
              return ListView.builder(
                padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                itemCount: drivers.length,
                itemBuilder: (context, index) {
                  final user = drivers[index];
                  return Card(
                    color: const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0)),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 4,
                    child: ListTile(
                      leading: Icon(
                        user.onRoute
                            ? Icons.local_shipping
                            : Icons.check_circle_outline,
                        color: user.onRoute
                            ? Colors.white
                            : Colors.green, // "En ruta" ahora es blanco
                        size: 30,
                      ),
                      title: Text(
                        toBeginningOfSentenceCase(user.name) ?? user.name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        user.rut.toUpperCase(),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Chip(
                              label: Text(
                                user.role[0].toUpperCase() +
                                    user.role.substring(1),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11),
                              ),
                              backgroundColor: user.role.contains('admin')
                                  ? Colors.purple.shade700
                                  : (user.role == 'interno'
                                      ? Colors.green.shade700
                                      : Colors.blue.shade700),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0, vertical: 0),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if ((widget.adminUser.role == 'super_admin' &&
                                  user.role != 'super_admin') ||
                              (widget.adminUser.role == 'admin' &&
                                  user.role != 'admin' &&
                                  user.role != 'super_admin'))
                            IconButton(
                              icon: const Icon(Icons.delete_forever,
                                  color: Colors.redAccent, size: 22),
                              tooltip: 'Eliminar Usuario',
                              onPressed: () =>
                                  _showDeleteConfirmationDialog(context, user),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.white70, size: 22),
                            tooltip: 'Editar Usuario',
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          DriverFormScreen(user: user)));
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(user: user),
                          ),
                        );
                      },
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
}
