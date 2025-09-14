import 'package:flutter/material.dart';
import '../db_helper.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import '../invoice_printer.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final Widget drawer;
  const CreateInvoiceScreen({super.key, required this.drawer});

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
  bool isCredit = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(title: const Text('Crear Factura')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Facturar al crédito",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Switch(
                    value: isCredit,
                    onChanged: (value) => setState(() => isCredit = value),
                  ),
                ],
              ),
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
                  setState(() => selectedCustomerId = value);
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
                  setState(() => selectedSellerId = value);
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
        ),
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
      setState(() => selectedItems.removeAt(index));
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
    if (selectedCustomerId == null || selectedSellerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe seleccionar cliente y vendedor')),
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
      final device = await FlutterBluetoothPrinter.selectDevice(context);
      if (device == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se seleccionó ninguna impresora')),
        );
        return;
      }

      final invoice = await DBHelper.createInvoice(
        customerId: selectedCustomerId!,
        sellerId: selectedSellerId!,
        items: selectedItems,
        total: _total,
        isCredit: isCredit,
      );

      final invoiceId = invoice['id'];
      final createdAt = invoice['createdAt'] as DateTime;
      final printedAt = DateTime.now();

      // Crear modelo InvoiceData para ORIGINAL
      final invoiceData = InvoiceData(
        id: invoiceId,
        isCancelled: false,
        isPaid: !isCredit,
        type: 'ORIGINAL',
        createdAt: createdAt,
        printedAt: printedAt,
        customerName:
            customers.firstWhere((c) => c["id"] == selectedCustomerId)["name"]
                as String,
        sellerName:
            sellers.firstWhere((s) => s["id"] == selectedSellerId)["name"]
                as String,
        items: selectedItems,
        total: _total,
      );

      // Imprimir ORIGINAL
      await printInvoice(device, invoiceData);

      // Preguntar si imprimir copia
      final printCopy =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Impresión de Copia"),
              content: const Text("¿Desea imprimir una copia de la factura?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("No"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Sí, imprimir copia"),
                ),
              ],
            ),
          ) ??
          false;

      if (printCopy) {
        await printInvoice(device, invoiceData.copyWith(type: 'COPIA'));
      }

      setState(() => selectedItems.clear());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Factura generada e impresa correctamente'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
