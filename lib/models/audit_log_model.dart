import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogModel {
  final String adminId;
  final String adminName;
  final String action; // Ej: "VEHICLE_CREATED", "DRIVER_DEACTIVATED"
  final Timestamp timestamp;
  final Map<String, dynamic>
      details; // Datos extra, como la patente del vehículo afectado

  AuditLogModel({
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.timestamp,
    required this.details,
  });

  factory AuditLogModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return AuditLogModel(
      adminId: data['adminId'] ?? '',
      adminName: data['adminName'] ?? '',
      action: data['action'] ?? 'UNKNOWN',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      details: Map<String, dynamic>.from(data['details'] ?? {}),
    );
  }
}
