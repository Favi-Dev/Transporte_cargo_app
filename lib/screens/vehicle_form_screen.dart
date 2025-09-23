// Bloque 1: Importaciones
/// Importa los paquetes y archivos necesarios para la pantalla del formulario:
/// - `material.dart`: Para los widgets de Flutter.
/// - `vehicle_model.dart`: Para estructurar los datos del vehículo que se crea o edita.
/// - `firestore_service.dart`: Para la lógica de negocio de guardar/actualizar en Firestore.
/// - `curved_background_scaffold.dart`: Para el diseño base de la pantalla.
import 'package:flutter/material.dart';
import '../models/vehicle_model.dart';
import '../services/firestore_service.dart';
import '../widgets/curved_background_scaffold.dart';

// Bloque 2: Definición del StatefulWidget
/// Define la `VehicleFormScreen`, una pantalla con estado reutilizable que sirve tanto
/// para **añadir** un nuevo vehículo como para **editar** uno existente.
/// Su comportamiento cambia dependiendo de si recibe un objeto `VehicleModel` opcional
/// en su constructor. Si `vehicle` es nulo, está en modo "Añadir"; si no, en modo "Editar".
class VehicleFormScreen extends StatefulWidget {
  final VehicleModel? vehicle;
  const VehicleFormScreen({Key? key, this.vehicle}) : super(key: key);

  @override
  _VehicleFormScreenState createState() => _VehicleFormScreenState();
}

// Bloque 3: Clase de Estado
/// Clase que maneja el estado y la lógica de `VehicleFormScreen`.
class _VehicleFormScreenState extends State<VehicleFormScreen> {
  // Bloque 3.1: Variables de Estado y Controladores
  /// Declara todas las variables de estado para el formulario.
  /// Incluye la `_formKey` para validación, la instancia del `FirestoreService`,
  /// un `TextEditingController` por cada campo de texto, y variables para manejar
  /// el estado de carga, el tipo de vehículo seleccionado y el modo de edición.
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  final _patenteController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _ownerController = TextEditingController();

  String? _selectedType;
  bool _isLoading = false;

  /// Un `getter` booleano que simplifica la lógica en el resto del código.
  /// Devuelve `true` si se pasó un vehículo al widget, indicando que estamos en modo de edición.
  bool get isEditMode => widget.vehicle != null;

  final List<String> _vehicleTypes = [
    'tracto_camion',
    'semi_remolque',
    'camion'
  ];

  // Bloque 3.2: Método initState
  /// Método del ciclo de vida que se ejecuta al crear la pantalla.
  /// Contiene una lógica crucial: si la pantalla está en modo de edición (`isEditMode` es true),
  /// rellena todos los controladores del formulario con los datos del vehículo existente
  /// que se recibió en el constructor del widget.
  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      final vehicle = widget.vehicle!;
      _patenteController.text = vehicle.id;
      _brandController.text = vehicle.brand;
      _modelController.text = vehicle.model;
      _yearController.text = vehicle.year.toString();
      _colorController.text = vehicle.color;
      _ownerController.text = vehicle.owner;
      _selectedType = vehicle.type;
    }
  }

  // Bloque 3.3: Método _submitForm
  /// Método asíncrono que se ejecuta al presionar el botón de guardar.
  /// - Valida el formulario.
  /// - Activa el estado de carga.
  /// - Basándose en la variable `isEditMode`, decide si llamar a la función
  ///   `updateVehicle` o `addVehicle` del `FirestoreService`.
  /// - Muestra un `SnackBar` de éxito o error y cierra la pantalla si la operación fue exitosa.
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (isEditMode) {
        final updatedVehicle = VehicleModel(
          id: widget.vehicle!.id,
          brand: _brandController.text.trim(),
          model: _modelController.text.trim(),
          year: int.parse(_yearController.text.trim()),
          color: _colorController.text.trim(),
          owner: _ownerController.text.trim(),
          type: _selectedType!,
          status: widget.vehicle!.status,
          assignedTo: widget.vehicle!.assignedTo,
        );
        await _firestoreService.updateVehicle(updatedVehicle);
      } else {
        await _firestoreService.addVehicle(
          patente: _patenteController.text.trim().toUpperCase(),
          brand: _brandController.text.trim(),
          model: _modelController.text.trim(),
          year: int.parse(_yearController.text.trim()),
          color: _colorController.text.trim(),
          owner: _ownerController.text.trim(),
          type: _selectedType!,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Vehículo ${isEditMode ? 'actualizado' : 'añadido'} con éxito'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final action = isEditMode ? 'actualizar' : 'añadir';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al $action vehículo: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Bloque 3.4: Método dispose
  /// Método de limpieza del ciclo de vida. Libera los recursos de todos los
  /// `TextEditingController`s cuando la pantalla es eliminada para prevenir fugas de memoria.
  @override
  void dispose() {
    _patenteController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  // Bloque 3.5: Método Auxiliar _inputDecoration
  /// Función auxiliar que crea una decoración de `InputDecoration` estilizada y consistente
  /// para los campos de texto. Acepta un parámetro `enabled` para cambiar la apariencia
  /// visual si un campo está deshabilitado (como la patente en modo edición).
  InputDecoration _inputDecoration(String label,
      {String? hint, bool enabled = true}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey.shade300,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 2.0)),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0)),
    );
  }

  // Bloque 4: Método build
  /// Método principal que construye la interfaz visual del formulario.
  /// - La `AppBar` muestra un título diferente si se está añadiendo o editando.
  /// - El campo de la patente (`TextFormField`) se deshabilita cuando se está editando.
  /// - El texto del botón `ElevatedButton` cambia a 'Guardar Cambios' o 'Guardar Vehículo' según el modo.
  /// - Utiliza un `ListView` para asegurar que el formulario sea desplazable.
  @override
  Widget build(BuildContext context) {
    return CurvedBackgroundScaffold(
      appBar: AppBar(
          title:
              Text(isEditMode ? 'Editar Vehículo' : 'Añadir Nuevo Vehículo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _patenteController,
              enabled: !isEditMode,
              decoration: _inputDecoration('Patente (ID no editable)',
                  enabled: !isEditMode),
              textCapitalization: TextCapitalization.characters,
              validator: (value) =>
                  value!.isEmpty ? 'La patente es obligatoria' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
                controller: _brandController,
                decoration: _inputDecoration('Marca'),
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    value!.isEmpty ? 'La marca es obligatoria' : null),
            const SizedBox(height: 16),
            TextFormField(
                controller: _modelController,
                decoration: _inputDecoration('Modelo'),
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    value!.isEmpty ? 'El modelo es obligatorio' : null),
            const SizedBox(height: 16),
            TextFormField(
              controller: _yearController,
              decoration: _inputDecoration('Año'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value!.isEmpty) return 'El año es obligatorio';
                if (int.tryParse(value) == null)
                  return 'Por favor ingresa un número válido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
                controller: _colorController,
                decoration: _inputDecoration('Color'),
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    value!.isEmpty ? 'El color es obligatorio' : null),
            const SizedBox(height: 16),
            TextFormField(
                controller: _ownerController,
                decoration: _inputDecoration('Propietario (ej. fernandez spa)'),
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    value!.isEmpty ? 'El propietario es obligatorio' : null),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              hint: const Text('Tipo de Vehículo'),
              decoration: _inputDecoration('Tipo de Vehículo'),
              items: _vehicleTypes
                  .map((value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value.replaceAll('_', ' ').toUpperCase())))
                  .toList(),
              onChanged: (newValue) => setState(() => _selectedType = newValue),
              validator: (value) =>
                  value == null ? 'El tipo es obligatorio' : null,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEditMode ? 'Guardar Cambios' : 'Guardar Vehículo'),
            ),
          ],
        ),
      ),
    );
  }
}
