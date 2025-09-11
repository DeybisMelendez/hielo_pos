import 'package:flutter/material.dart';
import '../db_helper.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'dart:convert';
import 'dart:typed_data';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> sellers = [];

  List<Map<String, dynamic>> selectedItems = [];
  int? selectedCustomerId;
  int? selectedSellerId;
  ReceiptController? controller;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Cliente
          const Text(
            'Cliente',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          DropdownButton<int>(
            isExpanded: true,
            value: selectedCustomerId,
            hint: const Text('Selecciona un cliente'),
            items: customers.map((c) {
              return DropdownMenuItem<int>(
                value: c['id'] as int,
                child: Text(c['name']),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedCustomerId = value;
              });
            },
          ),

          // Vendedor
          const Text(
            'Vendedor',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          DropdownButton<int>(
            isExpanded: true,
            value: selectedSellerId,
            hint: const Text('Selecciona un vendedor'),
            items: sellers.map((s) {
              return DropdownMenuItem<int>(
                value: s['id'] as int,
                child: Text(s['name']),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedSellerId = value;
              });
            },
          ),

          const Divider(),

          // Lista de productos
          Expanded(
            child: ListView(
              children: products.map((p) {
                final selectedIndex = selectedItems.indexWhere(
                  (item) => item['product_id'] == p['id'],
                );
                final quantity = selectedIndex >= 0
                    ? selectedItems[selectedIndex]['quantity']
                    : 0;
                return ListTile(
                  title: Text(p['name']),
                  subtitle: Text('Precio: C\$ ${p['price']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (quantity > 0)
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () =>
                              _updateQuantity(selectedIndex, quantity - 1),
                        ),
                      Text(quantity.toString()),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _addProduct(p),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(),

          // Totales y botón
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: C\$ ${_total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton(
                onPressed: selectedItems.isEmpty ? null : _saveInvoice,
                child: const Text('Generar Factura'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    final prods = await DBHelper.getProducts();
    final custs = await DBHelper.getCustomers();
    final sels = await DBHelper.getSellers();
    setState(() {
      products = prods;
      customers = custs;
      sellers = sels;
      selectedCustomerId = customers.isNotEmpty ? customers.first['id'] : null;
      selectedSellerId = sellers.isNotEmpty ? sellers.first['id'] : null;
    });
  }

  void _addProduct(Map<String, dynamic> product) {
    final index = selectedItems.indexWhere(
      (item) => item['product_id'] == product['id'],
    );
    if (index >= 0) {
      _updateQuantity(index, selectedItems[index]['quantity'] + 1);
    } else {
      setState(() {
        selectedItems.add({
          'product_id': product['id'],
          'name': product['name'],
          'price': product['price'],
          'quantity': 1,
          'total': product['price'],
        });
      });
    }
  }

  void _updateQuantity(int index, int quantity) {
    if (quantity <= 0) {
      setState(() {
        selectedItems.removeAt(index);
      });
    } else {
      setState(() {
        selectedItems[index]['quantity'] = quantity;
        selectedItems[index]['total'] =
            selectedItems[index]['price'] * quantity;
      });
    }
  }

  double get _total {
    return selectedItems.fold(0, (sum, item) => sum + item['total']);
  }

  Future<void> _saveInvoice() async {
    // Validación básica
    if (selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe seleccionar un cliente')),
      );
      return;
    }

    if (selectedSellerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe seleccionar un vendedor')),
      );
      return;
    }

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe agregar al menos un producto')),
      );
      return;
    }

    try {
      // Seleccionar impresora antes de crear la factura
      final device = await FlutterBluetoothPrinter.selectDevice(context);
      if (device == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se seleccionó ninguna impresora')),
        );
        return;
      }

      // Guardar factura en la base de datos
      int invoiceId = await DBHelper.createInvoice(
        customerId: selectedCustomerId!,
        sellerId: selectedSellerId!,
        items: selectedItems,
        total: _total,
      );

      // Imprimir factura (original y copia)
      await _printInvoice(invoiceId, device);

      // Limpiar selección de productos
      setState(() {
        selectedItems.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Factura generada e impresa correctamente'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ocurrió un error al generar o imprimir la factura: $e',
          ),
        ),
      );
    }
  }

  Future<void> _printInvoice(int invoiceId, BluetoothDevice device) async {
    try {
      await _printPage(invoiceId, 'ORIGINAL', device);
    } catch (e) {
      debugPrint('Error al imprimir original: $e');
    }

    await Future.delayed(const Duration(seconds: 2));

    try {
      await _printPage(invoiceId, 'COPIA', device);
    } catch (e) {
      debugPrint('Error al imprimir copia: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hubo un error al imprimir la copia: $e')),
      );
    }
  }

  // _printPage ahora usa la impresora ya seleccionada
  Future<void> _printPage(
    int invoiceId,
    String type,
    BluetoothDevice device,
  ) async {
    if (selectedCustomerId == null ||
        selectedSellerId == null ||
        selectedItems.isEmpty) {
      throw Exception('Datos de factura incompletos');
    }

    final buffer = StringBuffer();
    buffer.writeln('*** FACTURA #$invoiceId - $type ***');
    buffer.writeln(
      'Cliente: ${customers.firstWhere((c) => c["id"] == selectedCustomerId)["name"]}',
    );
    buffer.writeln(
      'Vendedor: ${sellers.firstWhere((s) => s["id"] == selectedSellerId)["name"]}',
    );
    buffer.writeln('--------------------------------');

    for (var item in selectedItems) {
      final name = item['name'];
      final qty = item['quantity'];
      final price = item['price'];
      final total = item['total'];
      buffer.writeln('$name  x$qty   C\$${price.toStringAsFixed(2)}');
      buffer.writeln('                  C\$${total.toStringAsFixed(2)}');
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('TOTAL: C\$${_total.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('¡Gracias por su compra!');
    buffer.writeln('');
    buffer.writeln('');
    buffer.writeln('');

    Uint8List bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    bytes.addAll(Commands.cutPaper);

    await FlutterBluetoothPrinter.printBytes(
      data: bytes,
      address: device.address,
      keepConnected: false,
    );
  }
}
