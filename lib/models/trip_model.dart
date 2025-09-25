// lib/models/trip_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class TripModel {
  final String driverId;
  final String driverName;
  final Timestamp startTime;
  final Timestamp? endTime;
  final String vehicleId;
  final String? semiId;
  // CAMBIO: Se añade el campo para la primera salida.
  final String? firstOutput;

  TripModel({
    required this.driverId,
    required this.driverName,
    required this.startTime,
    this.endTime,
    required this.vehicleId,
    this.semiId,
    this.firstOutput, // CAMBIO: Se añade al constructor.
  });

  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return TripModel(
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? '',
      startTime: data['startTime'] ?? Timestamp.now(),
      endTime: data['endTime'],
      vehicleId: data['vehicleId'] ?? '',
      semiId: data['semiId'],
      // CAMBIO: Se lee el dato "first_output" desde Firestore.
      firstOutput: data['first_output'],
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
      'first_output': firstOutput,
    };
  }
}