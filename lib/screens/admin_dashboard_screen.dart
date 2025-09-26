import 'package:flutter/material.dart';
import 'package:fernandez_cargo_app/models/user_model.dart';
import 'package:fernandez_cargo_app/widgets/admin_views/available_vehicles_view.dart';
import 'package:fernandez_cargo_app/widgets/admin_views/ongoing_trips_view.dart';
import 'package:fernandez_cargo_app/widgets/admin_views/driver_list_view.dart';
import 'package:fernandez_cargo_app/widgets/admin_views/reports_view.dart'; // <-- NUEVA IMPORTACIÓN
import 'package:fernandez_cargo_app/theme/app_theme.dart';
import '../services/firestore_service.dart';
import 'vehicle_form_screen.dart';
import 'assign_trip_screen.dart';
import 'driver_form_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final UserModel adminUser;
  const AdminDashboardScreen({Key? key, required this.adminUser}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // <-- CAMBIO (antes 3)
    _tabController.addListener(() => setState(() {}));
    _firestoreService.cleanOldTrips();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildFloatingActionButton() {
    switch (_tabController.index) {
      case 0: // En Curso
        return FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AssignTripScreen()),
            );
          },
          label: const Text('Asignar Viaje'),
          icon: const Icon(Icons.add_road),
        );
      case 1: // Disponibles
        return FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VehicleFormScreen()),
            );
          },
          tooltip: 'Añadir Vehículo',
          child: const Icon(Icons.add),
        );
      case 2: // Choferes
        return FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DriverFormScreen()),
            );
          },
          tooltip: 'Añadir Chofer',
          child: const Icon(Icons.person_add),
        );
      case 3: // Reportes (sin FAB)
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard de Flota'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'En Curso', icon: Icon(Icons.local_shipping)),
            Tab(text: 'Disponibles', icon: Icon(Icons.event_available)),
            Tab(text: 'Choferes', icon: Icon(Icons.people)),
            Tab(text: 'Reportes', icon: Icon(Icons.assessment)), // <-- NUEVA TAB
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: ClipPath(
              clipper: _BottomWaveClipper(),
              child: Container(height: size.height * 0.2, color: AppTheme.primaryRed),
            ),
          ),
          TabBarView(
            controller: _tabController,
            children: [
              const OngoingTripsView(),
              const AvailableVehiclesView(),
              DriverListView(adminUser: widget.adminUser),
              const ReportsView(), // <-- NUEVA VISTA
            ],
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
}

class _BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..quadraticBezierTo(size.width / 2, size.height * 0.4, 0, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
