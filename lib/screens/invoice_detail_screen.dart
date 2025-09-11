import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  Map<String, dynamic>? invoice;
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic>? customer;
  Map<String, dynamic>? seller;

  bool loading = true;

  final currencyFormat = NumberFormat.currency(locale: 'es_NI', symbol: "C\$");

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    final db = await DBHelper.getDb();

    final invoices = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [widget.invoiceId],
      limit: 1,
    );

    if (invoices.isEmpty) {
      setState(() {
        loading = false;
      });
      return;
    }

    final invoiceData = invoices.first;

    final cust = invoiceData['customer_id'] != null
        ? await DBHelper.getCustomer(invoiceData['customer_id'] as int)
        : null;

    final sell = invoiceData['seller_id'] != null
        ? await DBHelper.getSeller(invoiceData['seller_id'] as int)
        : null;

    final rawInvoiceItems = await DBHelper.getInvoiceItems(widget.invoiceId);
    final invoiceItems = rawInvoiceItems
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    for (int i = 0; i < invoiceItems.length; i++) {
      final products = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [invoiceItems[i]['product_id']],
      );
      if (products.isNotEmpty) {
        invoiceItems[i]['product_name'] = products.first['name'];
      }
    }

    setState(() {
      invoice = invoiceData;
      items = invoiceItems;
      customer = cust;
      seller = sell;
      loading = false;
    });
  }

  /// Función para formatear fecha manualmente en formato dd/MM/yyyy
  String formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (invoice == null) {
      return const Scaffold(body: Center(child: Text("Factura no encontrada")));
    }

    return Scaffold(
      appBar: AppBar(title: Text("Factura #${invoice!['id']}")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Resumen de Factura
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Cliente: ${customer?['name'] ?? 'N/A'}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    "Vendedor: ${seller?['name'] ?? 'N/A'}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    "Fecha: ${formatDate(invoice!['date'])}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "C\$ ${invoice!['total']}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Lista de productos
          const Text(
            "Productos",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),

          ...items.map(
            (item) => Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                //leading: const Icon(Icons.shopping_cart, color: Colors.blue),
                title: Text(
                  item['product_name'] ?? 'Producto',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text("${item['quantity']} x C\$ ${item['price']}"),
                trailing: Text(
                  "C\$ ${item['total']}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
