import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'localization.dart';
import 'db_helper.dart';

/// Modelo de datos para una factura
class InvoiceData {
  final int id;
  final String type;
  final bool isCancelled;
  final bool isPaid;
  final String customerName;
  final String sellerName;
  final List<Map<String, dynamic>> items;
  final double total;
  final DateTime createdAt;
  final DateTime printedAt;

  InvoiceData({
    required this.id,
    required this.type,
    required this.customerName,
    required this.sellerName,
    required this.items,
    required this.total,
    required this.createdAt,
    required this.printedAt,
    required this.isCancelled,
    required this.isPaid,
  });

  /// Permite clonar un invoice cambiando solo algunos campos
  InvoiceData copyWith({
    int? id,
    String? type,
    String? customerName,
    String? sellerName,
    List<Map<String, dynamic>>? items,
    double? total,
    DateTime? createdAt,
    DateTime? printedAt,
    bool? isCancelled,
    bool? isPaid,
  }) {
    return InvoiceData(
      id: id ?? this.id,
      type: type ?? this.type,
      customerName: customerName ?? this.customerName,
      sellerName: sellerName ?? this.sellerName,
      items: items ?? this.items,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      printedAt: printedAt ?? this.printedAt,
      isCancelled: isCancelled ?? this.isCancelled,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}

/// Función reutilizable para imprimir facturas
Future<void> printInvoice(BluetoothDevice device, InvoiceData invoice) async {
  final BytesBuilder builder = BytesBuilder();
  final createdStr = Localization().formatDate(invoice.createdAt);

  final printedStr = Localization().formatDate(invoice.printedAt);

  // Inicializa la impresora y configura Latin1
  builder.add(Commands.initialize);
  builder.add(Uint8List.fromList([0x1B, 0x74, 16])); // Latin1 codepage

  // Encabezado con datos de la empresa
  builder.add(Commands.setAlignmentCenter);
  builder.add(
    latin1.encode(
      'Hielo Motastepe\n'
      'Autohotel Petate 500 mts al sur,\n'
      'Lotificación Santa María,\n'
      'Segunda etapa. Managua, Nic.\n'
      'Tel: 8814-4902\n\n',
    ),
  );
  builder.add(latin1.encode('FACTURA #${invoice.id}\n${invoice.type}\n\n'));
  builder.add(
    latin1.encode(
      'Estado: ${invoice.isCancelled ? 'ANULADA' : (invoice.isPaid ? 'PAGADA' : 'PENDIENTE')}\n',
    ),
  );
  builder.add(latin1.encode('$createdStr\n'));
  builder.add(Commands.setAlignmentLeft);
  builder.add(latin1.encode('--------------------------------\n'));

  // Datos de cliente y vendedor
  builder.add(latin1.encode('Cliente: ${invoice.customerName}\n'));
  builder.add(latin1.encode('Vendedor: ${invoice.sellerName}\n'));
  builder.add(latin1.encode('--------------------------------\n'));

  // Detalles de productos
  for (var item in invoice.items) {
    final product = await DBHelper.getProduct(item['product_id']);
    builder.add(
      latin1.encode(
        '${item['quantity']} x ${product?['name']}: C\$${item['price'].toStringAsFixed(2)}\n',
      ),
    );
    builder.add(Commands.setAlignmentRight);
    builder.add(
      latin1.encode('Total: C\$${item['total'].toStringAsFixed(2)}\n'),
    );
    builder.add(Commands.setAlignmentLeft);
  }

  builder.add(latin1.encode('--------------------------------\n'));
  builder.add(
    latin1.encode('TOTAL: C\$${invoice.total.toStringAsFixed(2)}\n\n'),
  );

  // Pie
  builder.add(Commands.setAlignmentCenter);
  builder.add(latin1.encode('Impreso el: $printedStr\n'));
  builder.add(latin1.encode('¡Gracias por su compra!\n\n'));
  builder.add(Commands.setAlignmentLeft);

  // Corte de papel
  builder.add(Commands.lineFeed);
  builder.add(Commands.lineFeed);
  builder.add(Commands.cutPaper);

  // Enviar a la impresora
  await FlutterBluetoothPrinter.printBytes(
    address: device.address,
    data: builder.toBytes(),
    keepConnected: true,
  );
}

/// Imprime un reporte de varias facturas
Future<void> printInvoiceReport(
  BluetoothDevice device,
  List<Map<String, dynamic>> invoices,
) async {
  final BytesBuilder builder = BytesBuilder();
  final nowStr = Localization().formatDateAndTime(DateTime.now());
  final grandTotal = invoices.fold<double>(
    0,
    (sum, inv) => sum + (inv['total'] as double? ?? 0),
  );

  // Inicializa la impresora y configura Latin1
  builder.add(Commands.initialize);
  builder.add(Uint8List.fromList([0x1B, 0x74, 16])); // Latin1 codepage

  // Encabezado del reporte
  builder.add(Commands.setAlignmentCenter);
  builder.add(
    latin1.encode(
      'Hielo Motastepe\n'
      'Reporte de Facturas\n'
      'Fecha: $nowStr\n\n',
    ),
  );

  builder.add(Commands.setAlignmentLeft);
  builder.add(latin1.encode('--------------------------------\n'));

  for (var inv in invoices) {
    final customer = await DBHelper.getCustomer(inv['customer_id']);
    final seller = await DBHelper.getSeller(inv['seller_id']);
    final customerName = customer?['name'] ?? 'Desconocido';
    final sellerName = seller?['name'] ?? 'Desconocido';
    final dateStr = inv['date'] != null
        ? Localization().formatDate(DateTime.parse(inv['date']))
        : '';
    final totalStr = inv['total']?.toStringAsFixed(2) ?? '0.00';

    builder.add(
      latin1.encode(
        'Fact # ${inv['id']} - $customerName\n'
        'Estado: ${inv['is_cancelled'] == 1 ? 'ANULADA' : (inv['is_paid'] == 1 ? 'PAGADA' : 'PENDIENTE')}\n'
        'Vendedor: ${sellerName.padRight(12)}\n'
        'Fecha: $dateStr\n'
        'Total: C\$ $totalStr\n'
        '--------------------------------\n',
      ),
    );
  }
  builder.add(
    latin1.encode('Gran Total: C\$${grandTotal.toStringAsFixed(2)}\n'),
  );
  builder.add(latin1.encode('Cantidad de facturas: ${invoices.length}\n'));

  // Pie
  builder.add(Commands.setAlignmentCenter);
  builder.add(latin1.encode('Fin del reporte\n\n'));
  builder.add(Commands.setAlignmentLeft);

  // Corte de papel
  builder.add(Commands.lineFeed);
  builder.add(Commands.lineFeed);
  builder.add(Commands.cutPaper);

  // Enviar a la impresora
  await FlutterBluetoothPrinter.printBytes(
    address: device.address,
    data: builder.toBytes(),
    keepConnected: true,
  );
}
