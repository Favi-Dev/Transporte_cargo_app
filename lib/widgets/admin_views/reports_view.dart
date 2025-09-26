// lib/widgets/admin_views/reports_view.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/report_service.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({Key? key}) : super(key: key);

  @override
  _ReportsViewState createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  final FirestoreService _firestoreService = FirestoreService();
  final ReportService _reportService = ReportService();

  List<UserModel> _drivers = [];
  UserModel? _selectedDriver;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      _drivers = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);
    try {
      final trips = await _firestoreService.getTripsForReport(
        driverId: _selectedDriver?.uid,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (trips.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontraron viajes con esos filtros.'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      await _reportService.generateTripReport(trips, _drivers);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar el reporte: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text('Generador de Reportes', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),

        // ==========================================================
        // CAMBIO: Se envuelve el Dropdown en un Row para añadir el botón
        // ==========================================================
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: DropdownButtonFormField<UserModel>(
                value: _selectedDriver,
                decoration: _inputDecoration('Filtrar por Chofer (Opcional)'),
                hint: const Text('Todos los choferes'),
                items: _drivers.map((driver) {
                  return DropdownMenuItem<UserModel>(
                    value: driver,
                    child: Text(driver.name),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedDriver = value),
              ),
            ),
            // Si hay un chofer seleccionado, muestra el botón de limpiar.
            if (_selectedDriver != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  tooltip: 'Limpiar filtro',
                  onPressed: () {
                    setState(() {
                      _selectedDriver = null;
                    });
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Filtros de Fecha
        Row(
          children: [
            Expanded(
              child: _buildDateSelector(context, isStartDate: true),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateSelector(context, isStartDate: false),
            ),
          ],
        ),
        const SizedBox(height: 32),
        
        // Botón de Generar Reporte
        _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Generar y Descargar Reporte'),
              onPressed: _generateReport,
            ),
      ],
    );
  }

  Widget _buildDateSelector(BuildContext context, {required bool isStartDate}) {
    final date = isStartDate ? _startDate : _endDate;
    final label = isStartDate ? 'Fecha de Inicio' : 'Fecha de Fin';

    return InkWell(
      onTap: () => _selectDate(context, isStartDate),
      child: InputDecorator(
        decoration: _inputDecoration(label),
        child: Text(
          date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Seleccionar...',
        ),
      ),
    );
  }
  
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}