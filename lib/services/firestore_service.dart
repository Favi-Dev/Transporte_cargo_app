// lib/services/firestore_service.dart

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/vehicle_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> _createAuditLog({
    required String action,
    required Map<String, dynamic> details,
    WriteBatch? batch,
  }) async {
    final adminUser = _auth.currentUser;
    if (adminUser == null) return;

    final adminDoc =
        await _firestore.collection('users').doc(adminUser.uid).get();
    final adminName = adminDoc.data()?['name'] ?? 'Admin Desconocido';

    final logData = {
      'adminId': adminUser.uid,
      'adminName': adminName,
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
      'details': details,
    };

    final logRef = _firestore.collection('audit_logs').doc();

    if (batch != null) {
      batch.set(logRef, logData);
    } else {
      await logRef.set(logData);
    }
  }

  /// CORRECCIÓN CLAVE: Este método ahora es la ÚNICA fuente de creación de viajes.
  Future<void> assignVehiclesToDriver({
    required String vehicleId,
    String? semiId,
    String? firstOutput,
    String? routeDocumentUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuario no autenticado.");

    final driverUid = user.uid;
    final batch = _firestore.batch();
    final userDocRef = _firestore.collection('users').doc(driverUid);

    // Obtenemos el nombre del chofer para guardarlo directamente en el viaje.
    final userDoc = await userDocRef.get();
    final driverName = userDoc.data()?['name'] ?? 'Nombre no encontrado';

    // 1. Actualiza el estado del usuario.
    batch.update(userDocRef, {
      'on_route': true,
      'current_vehicle': vehicleId,
      'current_semi': semiId,
      'departure_time': FieldValue.serverTimestamp(),
    });

    // 2. Actualiza el estado de los vehículos.
    final vehicleDocRef = _firestore.collection('vehicles').doc(vehicleId);
    batch.update(
        vehicleDocRef, {'status': 'ocupado', 'assigned_to': driverUid});

    if (semiId != null) {
      final semiDocRef = _firestore.collection('vehicles').doc(semiId);
      batch.update(semiDocRef, {'status': 'ocupado', 'assigned_to': driverUid});
    }

    // 3. Crea el documento ÚNICO del viaje con toda la información inicial.
    final tripDocRef = _firestore.collection('trips').doc();
    batch.set(tripDocRef, {
      'driverId': driverUid,
      'driverName': driverName, // Guardamos el nombre aquí.
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'vehicleId': vehicleId,
      'semiId': semiId,
      'first_output': firstOutput,
      'route_document_url': routeDocumentUrl,
    });

    await batch.commit();
  }

  Future<void> addVehicle({
    required String patente,
    required String brand,
    required String model,
    required int year,
    required String color,
    required String owner,
    required String type,
  }) async {
    final docRef = _firestore.collection('vehicles').doc(patente);
    await docRef.set({
      'brand': brand,
      'model': model,
      'year': year,
      'color': color,
      'owner': owner.toLowerCase(),
      'type': type,
      'status': 'disponible',
      'assigned_to': null,
    });

    await _createAuditLog(
      action: 'VEHICLE_CREATED',
      details: {'vehicleId': patente, 'brand': brand, 'model': model},
    );
  }

  /// CORRECCIÓN CLAVE: Este método ya NO crea un viaje. Solo busca el viaje
  /// activo y lo actualiza para marcarlo como finalizado.
  Future<void> releaseVehiclesFromDriver() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuario no autenticado.");

    final driverUid = user.uid;
    final batch = _firestore.batch();

    // 1. Busca el viaje activo del chofer (donde endTime no existe).
    final tripQuery = await _firestore
        .collection('trips')
        .where('driverId', isEqualTo: driverUid)
        .where('endTime', isEqualTo: null)
        .limit(1)
        .get();

    if (tripQuery.docs.isNotEmpty) {
      // Si encuentra el viaje activo, lo actualiza.
      final tripDocRef = tripQuery.docs.first.reference;
      batch.update(tripDocRef, {'endTime': FieldValue.serverTimestamp()});
    }

    // 2. Libera los vehículos que el chofer tiene asignados.
    final vehicleQuery = await _firestore
        .collection('vehicles')
        .where('assigned_to', isEqualTo: driverUid)
        .get();

    for (final doc in vehicleQuery.docs) {
      batch.update(doc.reference, {'status': 'disponible', 'assigned_to': null});
    }

    // 3. Actualiza el estado del chofer.
    final userDocRef = _firestore.collection('users').doc(driverUid);
    batch.update(userDocRef, {
      'on_route': false,
      'current_vehicle': null,
      'current_semi': null,
      'departure_time': null,
    });

    await batch.commit();
  }

  Future<void> forceReleaseVehicleForDriver({required String driverUid}) async {
    final batch = _firestore.batch();

    final vehicleQuery = await _firestore
        .collection('vehicles')
        .where('assigned_to', isEqualTo: driverUid)
        .get();

    for (final vehicleDoc in vehicleQuery.docs) {
      batch.update(
          vehicleDoc.reference, {'status': 'disponible', 'assigned_to': null});
    }

    // También actualizamos el viaje activo para marcarlo como finalizado.
    final tripQuery = await _firestore
        .collection('trips')
        .where('driverId', isEqualTo: driverUid)
        .where('endTime', isEqualTo: null)
        .limit(1)
        .get();

    if (tripQuery.docs.isNotEmpty) {
      batch.update(
          tripQuery.docs.first.reference, {'endTime': FieldValue.serverTimestamp()});
    }

    final userDocRef = _firestore.collection('users').doc(driverUid);
    batch.update(userDocRef, {
      'on_route': false,
      'current_vehicle': null,
      'current_semi': null,
      'departure_time': null,
    });

    await _createAuditLog(
      action: 'TRIP_FORCED_RELEASE',
      details: {'driverUid': driverUid},
      batch: batch,
    );

    await batch.commit();
  }

  Future<void> updateVehicle(VehicleModel vehicle) async {
    final docRef = _firestore.collection('vehicles').doc(vehicle.id);
    await docRef.update(vehicle.toFirestore());

    await _createAuditLog(
      action: 'VEHICLE_UPDATED',
      details: {'vehicleId': vehicle.id},
    );
  }

  Future<void> assignVehiclesToDriverByAdmin({
    required String driverUid,
    required String vehicleId,
    String? semiId,
  }) async {
    final batch = _firestore.batch();

    final userDocRef = _firestore.collection('users').doc(driverUid);
    final userDoc = await userDocRef.get();
    final driverName = userDoc.data()?['name'] ?? '';

    final departureTime = FieldValue.serverTimestamp();

    batch.update(userDocRef, {
      'on_route': true,
      'current_vehicle': vehicleId,
      'current_semi': semiId,
      'departure_time': departureTime,
    });

    final vehicleDocRef = _firestore.collection('vehicles').doc(vehicleId);
    batch.update(
        vehicleDocRef, {'status': 'ocupado', 'assigned_to': driverUid});

    if (semiId != null) {
      final semiDocRef = _firestore.collection('vehicles').doc(semiId);
      batch.update(semiDocRef, {'status': 'ocupado', 'assigned_to': driverUid});
    }

    final tripDocRef = _firestore.collection('trips').doc();
    batch.set(tripDocRef, {
      'driverId': driverUid,
      'driverName': driverName,
      'startTime': departureTime,
      'endTime': null,
      'vehicleId': vehicleId,
      'semiId': semiId,
    });

    await _createAuditLog(
      action: 'TRIP_MANUALLY_ASSIGNED',
      details: {'driverUid': driverUid, 'vehicleId': vehicleId},
      batch: batch,
    );

    await batch.commit();
  }

  Future<void> createNewDriver({
    required String name,
    required String rut,
    required String phone,
    required String email,
    required String role,
    required String password,
  }) async {
    final authEmail = '${rut.trim()}@fernandezcargo.cl';
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      User? newUser = userCredential.user;
      if (newUser == null) {
        throw Exception(
            "No se pudo crear el usuario en Firebase Authentication.");
      }

      await _firestore.collection('users').doc(newUser.uid).set({
        'name': name,
        'rut': rut,
        'phone': phone,
        'email': email,
        'role': role,
        'on_route': false,
        'current_vehicle': null,
        'current_semi': null,
        'departure_time': null,
        'profile_picture_url': null,
      });

      await _createAuditLog(
        action: 'DRIVER_CREATED',
        details: {'driverRut': rut, 'driverName': name, 'driverRole': role},
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('El RUT ingresado ya está registrado como un chofer.');
      } else if (e.code == 'weak-password') {
        throw Exception('La contraseña proporcionada es demasiado débil.');
      } else {
        throw Exception('Error de Firebase Authentication: ${e.message}');
      }
    } catch (e) {
      throw Exception('Ocurrió un error inesperado al crear el chofer: $e');
    }
  }

  Future<void> uploadProfilePicture(
      String driverUid, Uint8List fileBytes) async {
    try {
      final ref = _storage.ref('profile_pictures/$driverUid');
      await ref.putData(fileBytes);
      final downloadUrl = await ref.getDownloadURL();
      await _firestore
          .collection('users')
          .doc(driverUid)
          .update({'profile_picture_url': downloadUrl});
    } catch (e) {
      throw Exception('Error al subir la imagen: $e');
    }
  }

  Future<void> cleanOldTrips() async {
    print("Iniciando revisión de viajes antiguos...");
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 60));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      final query = _firestore
          .collection('trips')
          .where('endTime', isLessThanOrEqualTo: cutoffTimestamp);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        print("No se encontraron viajes antiguos para eliminar.");
        return;
      }

      print(
          "Se encontraron ${snapshot.docs.length} viajes para eliminar. Procediendo...");
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print("Limpieza de viajes antiguos completada con éxito.");
    } catch (e) {
      print("Ocurrió un error durante la limpieza de viajes antiguos: $e");
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    final docRef = _firestore.collection('vehicles').doc(vehicleId);
    await docRef.delete();

    await _createAuditLog(
      action: 'VEHICLE_DELETED',
      details: {'vehicleId': vehicleId},
    );
  }

  Future<void> updateUser({
    required String uid,
    required String name,
    required String rut,
    required String phone,
    required String email,
    required String role,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);
    await docRef.update({
      'name': name,
      'rut': rut,
      'phone': phone,
      'email': email,
      'role': role,
    });

    await _createAuditLog(
      action: 'USER_UPDATED',
      details: {'userId': uid, 'userName': name},
    );
  }

  Future<void> deactivateDriver(String driverUid) async {
    final docRef = _firestore.collection('users').doc(driverUid);
    await docRef.update({'role': 'disabled'});

    await _createAuditLog(
      action: 'DRIVER_DEACTIVATED',
      details: {'driverUid': driverUid},
    );
  }

  Future<String> uploadRouteDocument(Uint8List fileBytes) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuario no autenticado.");

    try {
      final storagePath =
          'route_documents/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref(storagePath);
      await ref.putData(fileBytes);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Error al subir el documento de ruta: $e');
    }
  }
}