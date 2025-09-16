import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'db_helper.dart';

Future<String> exportInvoicesToCSV(List<Map<String, dynamic>> invoices) async {
  final List<List<String>> rows = [];

  // Encabezados
  rows.add([
    'Fecha',
    'Factura',
    'Tipo',
    'Estado',
    'Cliente',
    'Vendedor',
    'Cantidad',
    'Producto',
    'Total Producto',
  ]);

  for (var inv in invoices) {
    final customer =
        await DBHelper.getCustomer(inv['customer_id']) ??
        {'name': 'Desconocido'};
    final seller =
        await DBHelper.getSeller(inv['seller_id']) ?? {'name': 'Desconocido'};

    final dateStr = inv['date'] ?? '';
    final status = inv['is_cancelled'] == 1
        ? 'ANULADA'
        : (inv['is_paid'] == 1 ? 'PAGADA' : 'PENDIENTE');
    final type = inv['is_credit'] == 1 ? 'CRÉDITO' : 'CONTADO';

    // Obtener items de la factura
    final items = await DBHelper.getInvoiceItems(inv['id']);

    for (var item in items) {
      final product = await DBHelper.getProducts().then((products) {
        return products.firstWhere(
          (p) => p['id'] == item['product_id'],
          orElse: () => {'name': 'Desconocido'},
        );
      });

      rows.add([
        dateStr,
        inv['id'].toString(),
        type,
        status,
        customer['name'],
        seller['name'],
        item['quantity'].toString(),
        product['name'],
        item['total'].toStringAsFixed(2),
      ]);
    }
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
