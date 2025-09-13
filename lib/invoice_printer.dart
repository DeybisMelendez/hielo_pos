import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';

/// Modelo de datos para una factura
class InvoiceData {
  final int id;
  final String type;
  final String customerName;
  final String sellerName;
  final List<Map<String, dynamic>> items;
  final double total;

  InvoiceData({
    required this.id,
    required this.type,
    required this.customerName,
    required this.sellerName,
    required this.items,
    required this.total,
  });

  /// Permite clonar un invoice cambiando solo algunos campos
  InvoiceData copyWith({
    int? id,
    String? type,
    String? customerName,
    String? sellerName,
    List<Map<String, dynamic>>? items,
    double? total,
  }) {
    return InvoiceData(
      id: id ?? this.id,
      type: type ?? this.type,
      customerName: customerName ?? this.customerName,
      sellerName: sellerName ?? this.sellerName,
      items: items ?? this.items,
      total: total ?? this.total,
    );
  }
}

/// Función reutilizable para imprimir facturas
Future<void> printInvoice(BluetoothDevice device, InvoiceData invoice) async {
  final BytesBuilder builder = BytesBuilder();

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
  builder.add(
    latin1.encode('*** FACTURA #${invoice.id} - ${invoice.type} ***\n\n'),
  );

  // Datos de cliente y vendedor
  builder.add(Commands.setAlignmentLeft);
  builder.add(latin1.encode('Cliente: ${invoice.customerName}\n'));
  builder.add(latin1.encode('Vendedor: ${invoice.sellerName}\n'));
  builder.add(latin1.encode('--------------------------------\n'));

  // Detalles de productos
  for (var item in invoice.items) {
    builder.add(
      latin1.encode(
        '${item['quantity']} x ${item['name']}: C\$${item['price'].toStringAsFixed(2)}\n',
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
