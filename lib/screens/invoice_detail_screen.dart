import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../invoice_printer.dart';
import '../localization.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;
  final Widget drawer;

  const InvoiceDetailScreen({
    super.key,
    required this.invoiceId,
    required this.drawer,
  });

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
      setState(() => loading = false);
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

    final invoiceItems = <Map<String, dynamic>>[];
    for (var item in rawInvoiceItems) {
      final products = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [item['product_id']],
      );
      invoiceItems.add({
        ...item,
        'product_name': products.isNotEmpty
            ? products.first['name']
            : 'Producto',
      });
    }

    setState(() {
      invoice = invoiceData;
      items = invoiceItems;
      customer = cust;
      seller = sell;
      loading = false;
    });
  }

  Future<void> _reprintInvoice() async {
    if (invoice == null) return;

    final device = await FlutterBluetoothPrinter.selectDevice(context);
    if (device == null) return;

    final invoiceData = InvoiceData(
      id: invoice!['id'],
      isCancelled: invoice!['is_cancelled'] == 1,
      isPaid: invoice!['is_paid'] == 1,
      type: 'REIMPRESIÓN',
      customerName: customer?['name'] ?? 'N/A',
      sellerName: seller?['name'] ?? 'N/A',
      items: items
          .map(
            (e) => {
              'name': e['product_name'],
              'quantity': e['quantity'],
              'price': e['price'],
              'total': e['total'],
            },
          )
          .toList(),
      total: invoice!['total'],
      createdAt: DateTime.parse(invoice!['date']),
      printedAt: DateTime.now(),
    );

    await printInvoice(device, invoiceData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Factura reimpresa correctamente")),
    );
  }

  Future<void> _markPaid() async {
    if (invoice == null || invoice!['is_paid'] == 1) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar pago"),
        content: const Text("¿Desea marcar esta factura como pagada?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sí, pagar"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await DBHelper.markInvoicePaid(invoice!['id']);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Factura marcada como pagada")),
    );
    await _loadInvoice();
  }

  Future<void> _markCancelled() async {
    if (invoice == null || invoice!['is_cancelled'] == 1) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar anulación"),
        content: const Text(
          "¿Desea anular esta factura? Esta acción no se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sí, anular"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await DBHelper.markInvoiceCancelled(invoice!['id']);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Factura anulada")));
    await _loadInvoice();
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
      drawer: widget.drawer,
      appBar: AppBar(
        title: Text("Factura #${invoice!['id']}"),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          if (invoice!['is_paid'] == 0 && invoice!['is_cancelled'] == 0)
            IconButton(
              icon: const Icon(Icons.payments, color: Colors.green),
              onPressed: _markPaid,
              tooltip: 'Marcar como pagada',
            ),

          if (invoice!['is_cancelled'] == 0)
            IconButton(
              icon: const Icon(Icons.block, color: Colors.red),
              onPressed: _markCancelled,
              tooltip: 'Anular factura',
            ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _reprintInvoice,
            tooltip: 'Reimprimir factura',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                    "Tipo: ${invoice!['is_credit'] == 1 ? 'Crédito' : 'Contado'}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    "Estado: ${invoice!['is_cancelled'] == 1 ? 'Anulada' : (invoice!['is_paid'] == 1 ? 'Pagada' : 'Pendiente')}",
                    style: TextStyle(
                      fontSize: 16,
                      color: invoice!['is_cancelled'] == 1
                          ? Colors.red
                          : (invoice!['is_paid'] == 1
                                ? Colors.green
                                : Colors.orange),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Cliente: ${customer?['name'] ?? 'N/A'}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    "Vendedor: ${seller?['name'] ?? 'N/A'}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    "Fecha: ${Localization().formatDate(DateTime.parse(invoice!['date']))}",
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
