import 'package:flutter/material.dart';
import 'db_helper.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> sellers = [];

  List<Map<String, dynamic>> selectedItems = [];
  int? selectedCustomerId;
  int? selectedSellerId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prods = await DBHelper.getProducts();
    final custs = await DBHelper.getDb().then((db) => db.query('customers'));
    final sels = await DBHelper.getDb().then((db) => db.query('sellers'));
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
      // Si ya está agregado, aumentar cantidad
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
    if (selectedCustomerId == null ||
        selectedSellerId == null ||
        selectedItems.isEmpty)
      return;
    final db = await DBHelper.getDb();

    final invoiceId = await db.insert('invoices', {
      'customer_id': selectedCustomerId!,
      'seller_id': selectedSellerId!,
      'date': DateTime.now().toIso8601String(),
      'total': _total,
    });

    for (var item in selectedItems) {
      await db.insert('invoice_items', {
        'invoice_id': invoiceId,
        'product_id': item['product_id'],
        'quantity': item['quantity'],
        'price': item['price'],
        'total': item['total'],
      });
    }

    setState(() {
      selectedItems.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Factura generada correctamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generar Factura')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selección de cliente y vendedor

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
                    subtitle: Text('Precio: \$${p['price']}'),
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
                  'Total: \$$_total',
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
    );
  }
}
