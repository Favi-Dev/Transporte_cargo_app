// lib/models/trip_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class TripModel {
  final String driverId;
  final String driverName;
  final Timestamp startTime;
  final Timestamp? endTime;
  final String vehicleId;
  final String? semiId;
  final List<Map<String, dynamic>> stops;

  TripModel({
    required this.driverId,
    required this.driverName,
    required this.startTime,
    this.endTime,
    required this.vehicleId,
    this.semiId,
    required this.stops, // Se requiere la lista en el constructor.
  });

  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    // Se convierte la lista de Firestore a un tipo seguro en Dart.
    List<Map<String, dynamic>> stopsList =
        List<Map<String, dynamic>>.from(data['stops'] ?? []);

    return TripModel(
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? '',
      startTime: data['startTime'] ?? Timestamp.now(),
      endTime: data['endTime'],
      vehicleId: data['vehicleId'] ?? '',
      semiId: data['semiId'],
      stops: stopsList, // Se asigna la lista de paradas.
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'startTime': startTime,
      'endTime': endTime,
      'vehicleId': vehicleId,
      'semiId': semiId,
      'stops': stops, // Se guarda la lista de paradas.
    };
  }
}