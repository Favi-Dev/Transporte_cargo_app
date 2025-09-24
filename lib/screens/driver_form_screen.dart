import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../widgets/curved_background_scaffold.dart';

class DriverFormScreen extends StatefulWidget {
  // Ahora puede recibir un usuario existente (para editarlo) o no (para crearlo).
  final UserModel? user;
  const DriverFormScreen({Key? key, this.user}) : super(key: key);

  @override
  _DriverFormScreenState createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends State<DriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  final _nameController = TextEditingController();
  final _rutController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController(); // Email de contacto
  final _passwordController = TextEditingController();

  String? _selectedRole;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Un getter para saber fácilmente si estamos en modo edición.
  bool get isEditMode => widget.user != null;

  final List<String> _driverRoles = ['interno', 'externo', 'admin'];

  @override
  void initState() {
    super.initState();
    // Si estamos en modo edición, rellenamos el formulario con los datos existentes.
    if (isEditMode) {
      final u = widget.user!;
      _nameController.text = u.name;
      _rutController.text = u.rut;
      _phoneController.text = u.phone;
      _emailController.text = u.email;
      _selectedRole = u.role;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (isEditMode) {
        // --- LÓGICA DE ACTUALIZACIÓN ---
        await _firestoreService.updateUser(
          uid: widget.user!.uid,
          name: _nameController.text.trim(),
          rut: _rutController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          role: _selectedRole!,
        );
      } else {
        // --- LÓGICA DE CREACIÓN (la que ya teníamos) ---
        await _firestoreService.createNewDriver(
          name: _nameController.text.trim(),
          rut: _rutController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          role: _selectedRole!,
          password: _passwordController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Chofer ${isEditMode ? 'actualizado' : 'creado'} con éxito'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error: ${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rutController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, {bool enabled = true}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey.shade200,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary, width: 2.0),
      ),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CurvedBackgroundScaffold(
      appBar: AppBar(
          title: Text(isEditMode ? 'Editar Chofer' : 'Añadir Nuevo Chofer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('Nombre Completo'),
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  value!.trim().isEmpty ? 'El nombre es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rutController,
              // El RUT (que se usa para el login) no se puede editar.
              enabled: !isEditMode,
              decoration: _inputDecoration('RUT (ej: 12345678-9)',
                  enabled: !isEditMode),
              validator: (value) =>
                  value!.trim().isEmpty ? 'El RUT es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: _inputDecoration('Email de Contacto'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'El email es obligatorio';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value))
                  return 'Por favor, introduce un email válido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: _inputDecoration('Teléfono'),
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  value!.trim().isEmpty ? 'El teléfono es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: _inputDecoration('Rol del Chofer'),
              items: _driverRoles
                  .map((role) => DropdownMenuItem<String>(
                        value: role,
                        child: Text(role[0].toUpperCase() + role.substring(1)),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedRole = value),
              validator: (value) =>
                  value == null ? 'Debes seleccionar un rol' : null,
            ),
            // El campo de contraseña solo aparece al CREAR un nuevo chofer.
            if (!isEditMode) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: _inputDecoration('Contraseña Inicial').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 6)
                    return 'La contraseña debe tener al menos 6 caracteres';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEditMode ? 'Guardar Cambios' : 'Guardar Chofer'),
            ),
          ],
        ),
      ),
    );
  }
}
