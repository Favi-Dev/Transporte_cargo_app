// lib/screens/confirmation_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../models/vehicle_model.dart';
import '../services/firestore_service.dart';
// CAMBIO: Importar el widget renombrado.
import '../widgets/curved_background_scaffold.dart';

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

class _ConfirmationPageState extends State<ConfirmationPage> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  final _firstOutputController = TextEditingController();
  Uint8List? _routeDocumentBytes;

  Future<VehicleModel> _getVehicleData(String id) async {
    final doc =
        await FirebaseFirestore.instance.collection('vehicles').doc(id).get();
    return VehicleModel.fromFirestore(doc);
  }

  Future<void> _pickDocumentImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _routeDocumentBytes = bytes;
      });
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

  void _startRoute() async {
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
      if (_routeDocumentBytes != null) {
        documentUrl =
            await _firestoreService.uploadRouteDocument(_routeDocumentBytes!);
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

  @override
  void dispose() {
    _firstOutputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CAMBIO: Se envuelve el contenido en un Scaffold...
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen de Selección')),
      // ...y se usa CurvedBackground en el body.
      body: CurvedBackground(
        child: Padding(
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
                          shape: const CircleBorder(),
                          color: const Color(0xFF212121),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _routeDocumentBytes != null
                                ? ClipOval(
                                    child: Image.memory(_routeDocumentBytes!,
                                        fit: BoxFit.cover),
                                  )
                                : const Icon(Icons.camera_alt,
                                    size: 50, color: Colors.white70),
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
                        fillColor:
                            Theme.of(context).cardColor.withOpacity(0.8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white70),
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
      ),
    );
  }
}