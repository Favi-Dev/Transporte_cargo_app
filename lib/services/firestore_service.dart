// lib/services/firestore_service.dart

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/vehicle_model.dart';
import '../models/trip_model.dart'; // Nueva importación

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
  /// CORRECCIÓN: Guardar la primera salida como la primera parada en 'stops'.
  /// CORRECCIÓN: Limpia viajes abiertos y crea el nuevo viaje con 'stops'
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

    // PASO CLAVE: Cerrar viajes anteriores sin endTime
    final oldTripsQuery = await _firestore
        .collection('trips')
        .where('driverId', isEqualTo: driverUid)
        .where('endTime', isEqualTo: null)
        .get();

    for (final doc in oldTripsQuery.docs) {
      batch.update(doc.reference, {'endTime': Timestamp.now()});
    }

    final userDocRef = _firestore.collection('users').doc(driverUid);
    final userDoc = await userDocRef.get();
    final driverName = userDoc.data()?['name'] ?? 'Nombre no encontrado';

    final now = Timestamp.now();

    // 1) Estado del usuario
    batch.update(userDocRef, {
      'on_route': true,
      'current_vehicle': vehicleId,
      'current_semi': semiId,
      'departure_time': now,
    });

    // 2) Estado de vehículos
    final vehicleDocRef = _firestore.collection('vehicles').doc(vehicleId);
    batch.update(vehicleDocRef, {'status': 'ocupado', 'assigned_to': driverUid});

    if (semiId != null) {
      final semiDocRef = _firestore.collection('vehicles').doc(semiId);
      batch.update(semiDocRef, {'status': 'ocupado', 'assigned_to': driverUid});
    }

    // 3) Documento del viaje
    final tripDocRef = _firestore.collection('trips').doc();
    batch.set(tripDocRef, {
      'driverId': driverUid,
      'driverName': driverName,
      'startTime': now,
      'endTime': null,
      'vehicleId': vehicleId,
      'semiId': semiId,
      'route_document_url': routeDocumentUrl,
      'stops': [
        {
          'location': firstOutput ?? 'Salida inicial no registrada',
          'timestamp': now,
        }
      ],
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

  /// CORRECCIÓN: Limpieza + creación de 'stops' en asignación por admin
  Future<void> assignVehiclesToDriverByAdmin({
    required String driverUid,
    required String vehicleId,
    String? semiId,
    String? firstOutput,        // nuevo
    String? routeDocumentUrl,   // nuevo
  }) async {
    final batch = _firestore.batch();

    // Limpieza de viajes abiertos sin endTime
    final oldTripsQuery = await _firestore
        .collection('trips')
        .where('driverId', isEqualTo: driverUid)
        .where('endTime', isEqualTo: null)
        .get();

    for (final doc in oldTripsQuery.docs) {
      batch.update(doc.reference, {'endTime': Timestamp.now()});
    }

    final userDocRef = _firestore.collection('users').doc(driverUid);
    final userDoc = await userDocRef.get();
    final driverName = userDoc.data()?['name'] ?? '';

    final departureTime = Timestamp.now();

    batch.update(userDocRef, {
      'on_route': true,
      'current_vehicle': vehicleId,
      'current_semi': semiId,
      'departure_time': departureTime,
    });

    final vehicleDocRef = _firestore.collection('vehicles').doc(vehicleId);
    batch.update(vehicleDocRef, {'status': 'ocupado', 'assigned_to': driverUid});

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
      'route_document_url': routeDocumentUrl,
      'stops': [
        {
          'location': firstOutput ?? 'Asignado por administrador',
          'timestamp': departureTime,
        }
      ]
    });

    await _createAuditLog(
      action: 'TRIP_MANUALLY_ASSIGNED',
      details: {
        'driverUid': driverUid,
        'vehicleId': vehicleId,
        if (semiId != null) 'semiId': semiId
      },
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

  /// ===================================================================
  /// CAMBIO: Admin puede subir documento para un chofer (driverUidForAdmin)
  /// ===================================================================
  Future<String> uploadRouteDocument(
    Uint8List fileBytes, {
    String? driverUidForAdmin,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado.');
    }

    final targetUid = driverUidForAdmin ?? user.uid;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('route_documents/$targetUid/$timestamp.jpg');

    await ref.putData(
      fileBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await ref.getDownloadURL();
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

  /// Elimina permanentemente el documento del chofer en Firestore.
  /// Nota: No elimina al usuario de Firebase Auth.
  Future<void> deleteDriver(String driverUid) async {
    final docRef = _firestore.collection('users').doc(driverUid);
    final userDoc = await docRef.get();
    final userName = userDoc.data()?['name'] ?? 'N/A';

    await docRef.delete();

    await _createAuditLog(
      action: 'DRIVER_DELETED',
      details: {'deletedDriverUid': driverUid, 'deletedDriverName': userName},
    );
  }

  /// Añade una nueva parada al viaje activo del conductor.
  Future<void> addStopToTrip(String stopLocation) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuario no autenticado.");

    // 1. Busca el viaje activo del chofer (endTime == null).
    final tripQuery = await _firestore
        .collection('trips')
        .where('driverId', isEqualTo: user.uid)
        .where('endTime', isEqualTo: null)
        .limit(1)
        .get();

    if (tripQuery.docs.isEmpty) {
      throw Exception("No se encontró un viaje activo para este conductor.");
    }

    final tripDocRef = tripQuery.docs.first.reference;

    // 2. Prepara la nueva parada.
    final newStop = {
      'location': stopLocation,
      'timestamp': Timestamp.now(), // CORRECCIÓN aplicada
    };

    // 3. Agrega la parada a la lista existente.
    await tripDocRef.update({
      'stops': FieldValue.arrayUnion([newStop]),
    });
  }

  /// ===================================================================
  /// NUEVO MÉTODO: Obtiene viajes para la generación de reportes.
  /// ===================================================================
  Future<List<TripModel>> getTripsForReport({
    String? driverId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Base: solo viajes finalizados (endTime != null).
    // ADVERTENCIA: isNotEqualTo: null puede requerir índice y en algunos casos no filtra exactamente "no null".
    Query query = _firestore.collection('trips').where('endTime', isNotEqualTo: null);

    if (driverId != null) {
      query = query.where('driverId', isEqualTo: driverId);
    }
    if (startDate != null) {
      query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      query = query.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    final snapshot = await query.orderBy('startTime', descending: true).get();

    return snapshot.docs.map((doc) => TripModel.fromFirestore(doc)).toList();
  }

}