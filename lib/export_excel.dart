import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

Future<String> exportInvoicesToExcel(
  List<Map<String, dynamic>> invoices,
) async {
  final excel = Excel.createExcel();
  final sheet = excel['Facturas'];

  // Encabezados
  sheet.appendRow([
    'ID',
    'Cliente',
    'Vendedor',
    'Fecha',
    'Total',
    'Estado',
    'Tipo',
  ]);

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

    sheet.appendRow([
      inv['id'],
      customerName,
      sellerName,
      dateStr,
      totalStr,
      status,
      type,
    ]);
  }

  // Guardar archivo
  final directory = await getApplicationDocumentsDirectory();
  final path =
      '${directory.path}/reporte_facturas_${DateTime.now().millisecondsSinceEpoch}.xlsx';
  final fileBytes = excel.encode();
  if (fileBytes != null) {
    final file = File(path);
    await file.writeAsBytes(fileBytes);
  }

  return path; // retorna la ruta del archivo
}
