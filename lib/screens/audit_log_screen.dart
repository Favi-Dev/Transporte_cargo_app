import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/audit_log_model.dart';
import '../widgets/curved_background_scaffold.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CurvedBackgroundScaffold(
      appBar: AppBar(
        title: const Text('Registros de Auditoría'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('audit_logs')
            .orderBy('timestamp', descending: true)
            .limit(100) // Mostramos los últimos 100 registros
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay registros de auditoría.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final log =
                  AuditLogModel.fromFirestore(snapshot.data!.docs[index]);
              final dateFormat = DateFormat('dd/MM/yy HH:mm');

              return Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.receipt_long, color: Colors.white70),
                  title: Text(
                    '${log.adminName} realizó: ${log.action}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${dateFormat.format(log.timestamp.toDate())}\nDetalles: ${log.details.toString()}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
