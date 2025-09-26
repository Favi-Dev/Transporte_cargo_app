// lib/services/report_service.dart

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import '../models/trip_model.dart';
import '../models/user_model.dart';

class ReportService {
  Future<void> generateTripReport(
      List<TripModel> trips, List<UserModel> drivers) async {
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, 'Reporte de Viajes');
    final Sheet sheet = excel['Reporte de Viajes'];

    final driverMap = {for (var d in drivers) d.uid: d.name};

    final List<String> headers = [
      'ID Viaje', 'Chofer', 'Vehículo Principal', 'Semi Remolque',
      'Fecha Inicio', 'Hora Inicio', 'Fecha Fin', 'Hora Fin',
      'Duración (HH:mm)', 'Paradas (Hora - Lugar)'
    ];
    
    // ==========================================================
    // CORRECCIÓN DEFINITIVA: Se usa la sintaxis de color correcta
    // para las versiones recientes del paquete 'excel'.
    // ==========================================================
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.red, // <-- Sintaxis correcta
      fontColorHex: ExcelColor.white      // <-- Sintaxis correcta
    );
    
    final dataCellStyle = CellStyle(
      verticalAlign: VerticalAlign.Top, 
      textWrapping: TextWrapping.WrapText
    );

    // Escribir cabeceras
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Escribir datos de los viajes
    for (var i = 0; i < trips.length; i++) {
      final trip = trips[i];
      final driverName = driverMap[trip.driverId] ?? trip.driverId;
      final startTime = trip.startTime.toDate();
      final endTime = trip.endTime?.toDate();

      String duration = 'N/A';
      if (endTime != null) {
        final diff = endTime.difference(startTime);
        final hours = diff.inHours;
        final minutes = diff.inMinutes.remainder(60);
        duration = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
      }
      
      final stopsFormatted = trip.stops.map((stop) {
        final time = (stop['timestamp'] as Timestamp).toDate();
        final location = stop['location'];
        return '${DateFormat('HH:mm').format(time)} - $location';
      }).join('\n');

      final tripIdShort = trip.driverId.length > 8 ? trip.driverId.substring(0, 8) : trip.driverId;

      final List<dynamic> rowData = [
        tripIdShort, driverName, trip.vehicleId, trip.semiId ?? 'N/A',
        DateFormat('dd/MM/yyyy').format(startTime), DateFormat('HH:mm').format(startTime),
        endTime != null ? DateFormat('dd/MM/yyyy').format(endTime) : 'En curso',
        endTime != null ? DateFormat('HH:mm').format(endTime) : '-',
        duration, stopsFormatted,
      ];
      
      for (var j = 0; j < rowData.length; j++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
        cell.value = TextCellValue(rowData[j].toString());
        cell.cellStyle = dataCellStyle;
      }
    }

    // Guardar y descargar
    final fileName = 'Reporte_FernandezCargo_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
    final bytes = excel.save();

    if (bytes != null) {
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
  }
}