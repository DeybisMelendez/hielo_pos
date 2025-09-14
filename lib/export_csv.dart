import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String> exportInvoicesToCSV(List<Map<String, dynamic>> invoices) async {
  final List<List<String>> rows = [];

  // Encabezados
  rows.add(['ID', 'Cliente', 'Vendedor', 'Fecha', 'Total', 'Estado', 'Tipo']);

  // Filas de datos
  for (var inv in invoices) {
    final customerName = inv['customer_name'] ?? 'Desconocido';
    final sellerName = inv['seller_name'] ?? 'Desconocido';
    final dateStr = inv['date'] != null
        ? DateTime.parse(inv['date']).toIso8601String()
        : '';
    final totalStr = inv['total']?.toStringAsFixed(2) ?? '0.00';
    final status = inv['is_cancelled'] == 1
        ? 'ANULADA'
        : (inv['is_paid'] == 1 ? 'PAGADA' : 'PENDIENTE');
    final type = inv['is_credit'] == 1 ? 'CRÉDITO' : 'CONTADO';

    rows.add([
      inv['id'].toString(),
      customerName,
      sellerName,
      dateStr,
      totalStr,
      status,
      type,
    ]);
  }

  // Convertir a CSV
  final csvData = const ListToCsvConverter().convert(rows);

  // Guardar archivo
  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/reporte_facturas.csv';
  final file = File(path);
  await file.writeAsString(csvData);

  return path;
}

Future<void> shareInvoiceReport(List<Map<String, dynamic>> invoices) async {
  try {
    // Generar CSV y obtener ruta
    final path = await exportInvoicesToCSV(invoices);

    // Compartir archivo
    await Share.shareXFiles([XFile(path)], text: 'Reporte de Facturas');
  } catch (e) {
    print('Error al compartir archivo: $e');
  }
}
