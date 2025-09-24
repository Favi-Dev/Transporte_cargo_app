// Bloque 1: Importaciones
/// Importaciones necesarias para el servicio.
/// - `dart:typed_data`: Para manejar los datos de archivos en bytes (usado en la subida de imágenes).
/// - `cloud_firestore.dart`: Para todas las operaciones con la base de datos Firestore.
/// - `firebase_auth.dart`: Para acceder al usuario autenticado.
/// - `firebase_storage.dart`: Para subir archivos a Firebase Storage.
/// - `vehicle_model.dart`: Para usar el modelo de datos de vehículos.
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/vehicle_model.dart';
import '../models/user_model.dart'; // Importamos UserModel

// Bloque 2: Definición de la Clase de Servicio
/// `FirestoreService` es una clase central que encapsula toda la lógica de negocio
/// y las interacciones con los servicios de Firebase (Firestore, Auth, Storage).
/// Esto permite que las pantallas (la UI) sean más limpias y solo se encarguen de
/// llamar a estos métodos, sin contener la lógica de base de datos directamente.
class FirestoreService {
  /// Bloque 2.1: Instancias de Firebase
  /// Se crean instancias únicas de los servicios de Firebase para ser reutilizadas
  /// en todos los métodos de esta clase, mejorando el rendimiento.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- NUEVO MÉTODO PRIVADO PARA CREAR LOGS ---
  Future<void> _createAuditLog({
    required String action,
    required Map<String, dynamic> details,
    WriteBatch? batch,
  }) async {
    final adminUser = _auth.currentUser;
    if (adminUser == null) return;

    final adminDoc = await _firestore.collection('users').doc(adminUser.uid).get();
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

  /// Bloque 2.2: assignVehiclesToDriver
  /// Asigna uno o más vehículos a un chofer que está iniciando una ruta.
  /// Utiliza un `WriteBatch` para asegurar que todas las operaciones (actualizar
  /// el usuario y los vehículos) se completen de forma atómica: o todas tienen
  /// éxito, o ninguna se aplica.
  /// Ahora acepta la primera salida y la URL del documento.
  Future<void> assignVehiclesToDriver({
    required String vehicleId,
    String? semiId,
    String? firstOutput, // Nuevo parámetro
    String? routeDocumentUrl, // Nuevo parámetro
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuario no autenticado.");

    final driverUid = user.uid;
    final batch = _firestore.batch();

    final userDocRef = _firestore.collection('users').doc(driverUid);
    batch.update(userDocRef, {
      'on_route': true,
      'current_vehicle': vehicleId,
      'current_semi': semiId,
      'departure_time': FieldValue.serverTimestamp(),
    });

    // La actualización del vehículo también debería ser parte de un batch
    final vehicleDocRef = _firestore.collection('vehicles').doc(vehicleId);
    batch.update(vehicleDocRef, {
      'status': 'ocupado',
      'assigned_to': driverUid,
    });

    if (semiId != null) {
      final semiDocRef = _firestore.collection('vehicles').doc(semiId);
      batch.update(semiDocRef, {
        'status': 'ocupado',
        'assigned_to': driverUid,
      });
    }

    // Nuevo: Crea un documento de 'trips' que incluye la nueva información.
    // Es mejor crear el trip aquí en lugar de en releaseVehiclesFromDriver.
    final tripDocRef = _firestore.collection('trips').doc();
    batch.set(tripDocRef, {
      'driverId': driverUid,
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null, // Viaje en curso
      'vehicleId': vehicleId,
      'semiId': semiId,
      'first_output': firstOutput, // Nuevo: Primera salida
      'route_document_url': routeDocumentUrl, // Nuevo: URL del documento
    });

    await batch.commit();
  }

  /// Bloque 2.3: addVehicle
  /// Añade un nuevo documento de vehículo a la colección `vehicles`. Esta función es
  /// llamada desde el formulario del administrador. La patente se usa como ID
  /// del documento para asegurar que sea única.
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

    // Añadimos el registro de auditoría
    await _createAuditLog(
      action: 'VEHICLE_CREATED',
      details: {'vehicleId': patente, 'brand': brand, 'model': model},
    );
  }

  /// Bloque 2.4: releaseVehiclesFromDriver
  /// Gestiona la finalización de un viaje por parte de un chofer.
  /// 1. Crea un nuevo documento en la colección `trips` con los detalles del viaje.
  /// 2. Actualiza el estado de los vehículos a 'disponible'.
  /// 3. Limpia el estado 'en ruta' del documento del chofer.
  /// Todas las operaciones se realizan en un `WriteBatch` para garantizar consistencia.
  Future<void> releaseVehiclesFromDriver() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuario no autenticado.");

    final driverUid = user.uid;
    final batch = _firestore.batch();

    final userDocRef = _firestore.collection('users').doc(driverUid);
    final userDoc = await userDocRef.get();
    if (!userDoc.exists) throw Exception("Documento de usuario no encontrado.");

    final userData = userDoc.data()!;
    final vehicleId = userData['current_vehicle'];
    final semiId = userData['current_semi'];
    final startTime = userData['departure_time'];
    final driverName = userData['name'];

    if (vehicleId != null && startTime != null) {
      final tripDocRef = _firestore.collection('trips').doc();
      batch.set(tripDocRef, {
        'driverId': driverUid,
        'driverName': driverName,
        'startTime': startTime,
        'endTime': FieldValue.serverTimestamp(),
        'vehicleId': vehicleId,
        'semiId': semiId,
      });
    }

    if (vehicleId != null) {
      final vehicleDocRef = _firestore.collection('vehicles').doc(vehicleId);
      batch.update(vehicleDocRef, {'status': 'disponible', 'assigned_to': null});
    }
    if (semiId != null) {
      final semiDocRef = _firestore.collection('vehicles').doc(semiId);
      batch.update(semiDocRef, {'status': 'disponible', 'assigned_to': null});
    }

    batch.update(userDocRef, {
      'on_route': false,
      'current_vehicle': null,
      'current_semi': null,
      'departure_time': null,
    });

    await batch.commit();
  }

  /// Bloque 2.5: forceReleaseVehicleForDriver
  /// Permite a un administrador forzar la liberación de los vehículos de un chofer.
  /// Limpia el estado del chofer y de todos los vehículos que tenía asignados.
  Future<void> forceReleaseVehicleForDriver({required String driverUid}) async {
    final batch = _firestore.batch();

    final vehicleQuery = await _firestore
        .collection('vehicles')
        .where('assigned_to', isEqualTo: driverUid)
        .get();

    for (final vehicleDoc in vehicleQuery.docs) {
      batch.update(vehicleDoc.reference, {
        'status': 'disponible',
        'assigned_to': null,
      });
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

  /// Bloque 2.6: updateVehicle
  /// Actualiza un documento de vehículo existente en Firestore. Recibe un objeto
  /// `VehicleModel` completo y utiliza su método `toFirestore()` para obtener
  /// el mapa de datos a actualizar.
  Future<void> updateVehicle(VehicleModel vehicle) async {
    final docRef = _firestore.collection('vehicles').doc(vehicle.id);
    await docRef.update(vehicle.toFirestore());

    await _createAuditLog(
      action: 'VEHICLE_UPDATED',
      details: {'vehicleId': vehicle.id},
    );
  }

  /// Bloque 2.7: assignVehiclesToDriverByAdmin
  /// Permite a un administrador asignar un viaje a un chofer. También crea un
  /// registro inicial en la colección `trips` con un `endTime` nulo, indicando
  /// que el viaje está activo.
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
    batch.update(vehicleDocRef, { 'status': 'ocupado', 'assigned_to': driverUid, });

    if (semiId != null) {
      final semiDocRef = _firestore.collection('vehicles').doc(semiId);
      batch.update(semiDocRef, { 'status': 'ocupado', 'assigned_to': driverUid, });
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

    // Añadimos el log al mismo batch para que sea atómico
    await _createAuditLog(
      action: 'TRIP_MANUALLY_ASSIGNED',
      details: {'driverUid': driverUid, 'vehicleId': vehicleId},
      batch: batch,
    );

    await batch.commit();
  }

  /// Bloque 2.8: createNewDriver
  /// Orquesta la creación completa de un nuevo chofer.
  /// 1. Crea el usuario en Firebase Authentication usando el RUT como base para el email.
  /// 2. Si tiene éxito, crea el documento correspondiente en la colección `users` de
  ///    Firestore, usando el UID de Authentication como ID del documento.
  /// 3. Maneja errores específicos de Firebase Auth.
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
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      User? newUser = userCredential.user;
      if (newUser == null) {
        throw Exception("No se pudo crear el usuario en Firebase Authentication.");
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

  /// Bloque 2.9: uploadProfilePicture
  /// Gestiona la subida de la foto de perfil de un usuario a Firebase Storage.
  /// 1. Crea una referencia en Storage dentro de la carpeta `profile_pictures/`.
  /// 2. Sube los datos del archivo en formato de bytes.
  /// 3. Obtiene la URL pública de descarga de la imagen.
  /// 4. Actualiza el campo `profile_picture_url` en el documento del usuario en Firestore.
  Future<void> uploadProfilePicture(String driverUid, Uint8List fileBytes) async {
    try {
      final ref = _storage.ref('profile_pictures/$driverUid');
      await ref.putData(fileBytes);
      final downloadUrl = await ref.getDownloadURL();
      await _firestore.collection('users').doc(driverUid).update({
        'profile_picture_url': downloadUrl,
      });
    } catch (e) {
      throw Exception('Error al subir la imagen: $e');
    }
  }

  /// Bloque 2.10: cleanOldTrips
  /// Tarea de mantenimiento que se ejecuta desde la app del administrador.
  /// Busca en la colección `trips` todos los viajes que finalizaron hace más de 60 días
  /// y los elimina en un solo batch para mantener la base de datos limpia.
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

      print("Se encontraron ${snapshot.docs.length} viajes para eliminar. Procediendo...");
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

  /// MÉTODO NUEVO: Elimina un documento de vehículo de Firestore.
  Future<void> deleteVehicle(String vehicleId) async {
    final docRef = _firestore.collection('vehicles').doc(vehicleId);
    await docRef.delete();

    await _createAuditLog(
      action: 'VEHICLE_DELETED',
      details: {'vehicleId': vehicleId},
    );
  }

  /// MÉTODO NUEVO: Actualiza los datos de un documento de usuario en Firestore.
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

  /// MÉTODO NUEVO: Desactiva un chofer en lugar de borrarlo.
  /// Cambia el rol a 'disabled' para que ya no aparezca en las listas activas.
  Future<void> deactivateDriver(String driverUid) async {
    final docRef = _firestore.collection('users').doc(driverUid);
    await docRef.update({'role': 'disabled'});

    await _createAuditLog(
      action: 'DRIVER_DEACTIVATED',
      details: {'driverUid': driverUid},
    );
  }

  /// Nuevo método en el Bloque 2 para subir el documento de ruta
  /// Sube el documento de ruta a Firebase Storage y devuelve su URL.
  Future<String> uploadRouteDocument(Uint8List fileBytes) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuario no autenticado.");

    try {
      final storagePath = 'route_documents/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref(storagePath);
      await ref.putData(fileBytes);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Error al subir el documento de ruta: $e');
    }
  }
}