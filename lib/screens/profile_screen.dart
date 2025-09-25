// lib/screens/profile_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'login_page.dart';
import 'audit_log_screen.dart';
// CAMBIO: Se importa el widget de fondo actualizado.
import '../widgets/curved_background_scaffold.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isUploading = false;

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  void _showSignOutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar la sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _signOut(context);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    setState(() => _isUploading = true);
    try {
      final picker = ImagePicker();
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final Uint8List fileBytes = await pickedFile.readAsBytes();
        await _firestoreService.uploadProfilePicture(
            widget.user.uid, fileBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Foto de perfil actualizada con éxito.'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    // CAMBIO: Ahora se retorna un Scaffold normal...
    return Scaffold(
      appBar: AppBar(title: Text('Perfil de ${user.name}')),
      // ...y el widget CurvedBackground se usa en el 'body'.
      body: CurvedBackground(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    backgroundImage: user.profilePictureUrl != null &&
                            user.profilePictureUrl!.isNotEmpty
                        ? NetworkImage(user.profilePictureUrl!) as ImageProvider
                        : null,
                    child: user.profilePictureUrl == null ||
                            user.profilePictureUrl!.isEmpty
                        ? Icon(Icons.person,
                            size: 80, color: Colors.white.withOpacity(0.8))
                        : null,
                  ),
                  if (_isUploading)
                    const Positioned.fill(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  else
                    Material(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _pickAndUploadImage,
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child:
                              Icon(Icons.edit, color: Colors.white, size: 20),
                        ),
                      ),
                    )
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.white70),
                      title: const Text('Nombre',
                          style: TextStyle(color: Colors.white)),
                      subtitle: Text(user.name,
                          style: const TextStyle(color: Colors.white70)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.badge, color: Colors.white70),
                      title:
                          const Text('RUT', style: TextStyle(color: Colors.white)),
                      subtitle: Text(user.rut,
                          style: const TextStyle(color: Colors.white70)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.email, color: Colors.white70),
                      title: const Text('Email de Contacto',
                          style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                          user.email.isNotEmpty ? user.email : 'No registrado',
                          style: const TextStyle(color: Colors.white70)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone, color: Colors.white70),
                      title: const Text('Teléfono',
                          style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                          user.phone.isNotEmpty ? user.phone : 'No registrado',
                          style: const TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            ),
            if (user.role == 'super_admin') ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Ver Registros de Auditoría'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AuditLogScreen()),
                    );
                  },
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () => _showSignOutConfirmationDialog(context),
                child: const Text('Cerrar Sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}