// lib/screens/vehicle_form_screen.dart

import 'package:flutter/material.dart';
import '../models/vehicle_model.dart';
import '../services/firestore_service.dart';
// CAMBIO: Importar el widget renombrado.
import '../widgets/curved_background_scaffold.dart';

class VehicleFormScreen extends StatefulWidget {
  final VehicleModel? vehicle;
  const VehicleFormScreen({Key? key, this.vehicle}) : super(key: key);

  @override
  _VehicleFormScreenState createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
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

  bool get isEditMode => widget.vehicle != null;

  final List<String> _vehicleTypes = [
    'tracto_camion',
    'semi_remolque',
    'camion'
  ];

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

  @override
  Widget build(BuildContext context) {
    // CAMBIO: Se envuelve el contenido en un Scaffold...
    return Scaffold(
      appBar: AppBar(
          title:
              Text(isEditMode ? 'Editar Vehículo' : 'Añadir Nuevo Vehículo')),
      // ...y se usa CurvedBackground en el body.
      body: CurvedBackground(
        child: Form(
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
                  decoration:
                      _inputDecoration('Propietario (ej. fernandez spa)'),
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
                onChanged: (newValue) =>
                    setState(() => _selectedType = newValue),
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
                    : Text(
                        isEditMode ? 'Guardar Cambios' : 'Guardar Vehículo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}