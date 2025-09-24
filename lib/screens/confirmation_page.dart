// Bloque 1: Importaciones
/// Importa todos los paquetes y archivos necesarios para la pantalla:
/// - `material.dart`: Widgets base de Flutter.
/// - `cloud_firestore.dart`: Para la interacción con Firestore.
/// - `vehicle_model.dart`: Para estructurar los datos de los vehículos.
/// - `firestore_service.dart`: Para la lógica de negocio.
/// - `curved_background_scaffold.dart`: Para el diseño base de la pantalla.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../models/vehicle_model.dart';
import '../services/firestore_service.dart';
import '../widgets/curved_background_scaffold.dart';

// Bloque 2: Definición del StatefulWidget
/// Define la pantalla `ConfirmationPage` como un `StatefulWidget`.
/// Esta pantalla muestra un resumen de los vehículos seleccionados por el chofer
/// y le pide una confirmación final antes de iniciar la ruta.
/// Recibe los IDs del vehículo y del semi como parámetros.
class ConfirmationPage extends StatefulWidget {
  final String vehicleId;
  final String? semiId;

  const ConfirmationPage({
    Key? key,
    required this.vehicleId,
    this.semiId,
  }) : super(key: key);

  @override
  _ConfirmationPageState createState() => _ConfirmationPageState();
}

// Bloque 3: Clase de Estado
/// Clase que maneja el estado y la lógica de la `ConfirmationPage`.
class _ConfirmationPageState extends State<ConfirmationPage> {
  // Bloque 3.1: Variables de Estado
  /// Declara las variables de estado:
  /// - `_firestoreService`: Una instancia del servicio para la lógica de negocio.
  /// - `_isLoading`: Una bandera booleana para controlar el estado de carga
  ///   del botón de confirmación, evitando múltiples clics.
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  // Nuevas variables de estado para el campo de texto y la imagen.
  final _firstOutputController = TextEditingController();
  Uint8List? _routeDocumentBytes; // Almacena los bytes de la imagen.

  // Bloque 3.2: Método _getVehicleData
  /// Función auxiliar asíncrona que busca y devuelve un único `VehicleModel`
  /// desde Firestore a partir de su ID (patente). Se usa en los `FutureBuilder`
  /// para cargar y mostrar los detalles de los vehículos seleccionados.
  Future<VehicleModel> _getVehicleData(String id) async {
    final doc =
        await FirebaseFirestore.instance.collection('vehicles').doc(id).get();
    return VehicleModel.fromFirestore(doc);
  }

  // Nuevo método para seleccionar una imagen de la galería.
  Future<void> _pickDocumentImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _routeDocumentBytes = bytes;
      });
      // Muestra un SnackBar para confirmar que la imagen fue seleccionada.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento de ruta seleccionado.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  // Bloque 3.3: Método _startRoute
  /// Método asíncrono que se ejecuta al presionar el botón 'INICIAR RUTA'.
  /// 1. Activa el estado de carga (`_isLoading = true`).
  /// 2. Llama al método `assignVehiclesToDriver` del `FirestoreService` para
  ///    actualizar la base de datos con la nueva asignación.
  /// 3. Muestra un `SnackBar` de éxito o error para informar al usuario del resultado.
  /// 4. Si la operación es exitosa, navega de vuelta a la pantalla principal.
  /// 5. Finalmente, desactiva el estado de carga.
  void _startRoute() async {
    // Validación del campo de texto
    if (_firstOutputController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, ingrese la primera salida.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? documentUrl;
      // Sube la imagen si se seleccionó una.
      if (_routeDocumentBytes != null) {
        // Asume que tienes un método para subir el documento. Lo implementaremos más abajo.
        documentUrl = await _firestoreService.uploadRouteDocument(_routeDocumentBytes!);
      }

      await _firestoreService.assignVehiclesToDriver(
        vehicleId: widget.vehicleId,
        semiId: widget.semiId,
        firstOutput: _firstOutputController.text.trim(),
        routeDocumentUrl: documentUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('¡Ruta iniciada con éxito!'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al iniciar la ruta: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Se añade el método dispose para limpiar el controlador.
  @override
  void dispose() {
    _firstOutputController.dispose();
    super.dispose();
  }

  // Bloque 4: Método build
  /// Método principal que construye la interfaz visual de la pantalla.
  /// - Utiliza `CurvedBackgroundScaffold` para mantener la estética de la app.
  /// - El cuerpo contiene `FutureBuilder`s que usan `_getVehicleData` para
  ///   mostrar las tarjetas de resumen del tracto/camión y del semi (si fue seleccionado).
  /// - El `ElevatedButton` al final activa la función `_startRoute` y muestra un
  ///   indicador de carga cuando la operación está en progreso.
  @override
  Widget build(BuildContext context) {
    return CurvedBackgroundScaffold(
      appBar: AppBar(title: const Text('Resumen de Selección')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Por favor, confirme su selección:',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            FutureBuilder<VehicleModel>(
              future: _getVehicleData(widget.vehicleId),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Card(
                      child: Center(child: CircularProgressIndicator()));
                final vehicle = snapshot.data!;
                return Card(
                    child: ListTile(
                        title: Text(vehicle.id.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${vehicle.brand} ${vehicle.model} (${vehicle.year})',
                            style: const TextStyle(color: Colors.white70)),
                        leading: const Icon(Icons.local_shipping,
                            size: 40, color: Colors.white70)));
              },
            ),
            if (widget.semiId != null)
              FutureBuilder<VehicleModel>(
                future: _getVehicleData(widget.semiId!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Card(
                        child: Center(child: CircularProgressIndicator()));
                  final semi = snapshot.data!;
                  return Card(
                      child: ListTile(
                          title: Text(semi.id.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${semi.brand} ${semi.model} (${semi.year})',
                              style: const TextStyle(color: Colors.white70)),
                          leading: const Icon(Icons.rv_hookup,
                              size: 40, color: Colors.white70)));
                },
              ),
            const SizedBox(height: 20),
            // Nuevo: Sección para subir imagen y campo de texto
            Text('Documento de ruta y primera salida:',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: InkWell(
                      onTap: _pickDocumentImage,
                      child: Card(
                        shape: const CircleBorder(), // Marco circular
                        color: const Color(0xFF212121), // Color actualizado
                        child: Padding(
                          padding: const EdgeInsets.all(16.0), // Ajuste de tamaño interno
                          child: _routeDocumentBytes != null
                              ? ClipOval(
                                  child: Image.memory(_routeDocumentBytes!, fit: BoxFit.cover),
                                )
                              : const Icon(Icons.camera_alt, size: 50, color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _firstOutputController,
                    decoration: InputDecoration(
                      labelText: 'Primera salida (Ej: LTS 456)',
                      filled: true,
                      fillColor: Theme.of(context).cardColor.withOpacity(0.8), // Estética de las tarjetas
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), // Bordes redondeados como las tarjetas
                        borderSide: BorderSide(color: Colors.white70), // Bordes visibles con color
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: _isLoading ? null : _startRoute,
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('INICIAR RUTA'),
            ),
          ],
        ),
      ),
    );
  }
}
