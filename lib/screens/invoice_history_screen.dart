// invoice_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../invoice_printer.dart';
import '../localization.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  DateTime? startDate;
  DateTime? endDate;
  double? minTotal;
  double? maxTotal;
  int? selectedCustomerId;
  int? selectedSellerId;

  List<Map<String, dynamic>> invoices = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> sellers = [];
  int currentPage = 0;
  final int pageSize = 20;

  final NumberFormat currencyFormat = NumberFormat.simpleCurrency();

  @override
  void initState() {
    super.initState();
    fetchFilters();
    fetchInvoices();
  }

  Future<void> fetchFilters() async {
    final c = await DBHelper.getCustomers();
    final s = await DBHelper.getSellers();
    setState(() {
      customers = c;
      sellers = s;
    });
  }

  Future<void> fetchInvoices() async {
    final offset = currentPage * pageSize;
    final data = await DBHelper.getInvoicesFiltered(
      startDate: startDate,
      endDate: endDate,
      minTotal: minTotal,
      maxTotal: maxTotal,
      limit: pageSize,
      offset: offset,
      customerId: selectedCustomerId,
      sellerId: selectedSellerId,
    );
    setState(() {
      invoices = data;
    });
  }

  Future<void> selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked.add(
            const Duration(hours: 23, minutes: 59, seconds: 59),
          );
        }
        currentPage = 0;
      });
      fetchInvoices();
    }
  }

  void clearFilters() {
    setState(() {
      startDate = null;
      endDate = null;
      minTotal = null;
      maxTotal = null;
      selectedCustomerId = null;
      selectedSellerId = null;
      currentPage = 0;
    });
    fetchInvoices();
  }

  void nextPage() {
    setState(() {
      currentPage++;
    });
    fetchInvoices();
  }

  void previousPage() {
    if (currentPage > 0) {
      setState(() {
        currentPage--;
      });
      fetchInvoices();
    }
  }

  Future<void> reprintInvoice(Map<String, dynamic> inv) async {
    try {
      final customer = await DBHelper.getCustomer(inv['customer_id']);
      final seller = await DBHelper.getSeller(inv['seller_id']);
      final items = await DBHelper.getInvoiceItems(inv['id']);

      final invoiceData = InvoiceData(
        id: inv['id'],
        isCancelled: inv['is_cancelled'] == 1,
        isPaid: inv['is_paid'] == 1,
        type: "REIMPRESIÓN",
        customerName: customer?['name'] ?? "Desconocido",
        sellerName: seller?['name'] ?? "Desconocido",
        items: items,
        total: inv['total'],
        createdAt: DateTime.parse(inv['date']),
        printedAt: DateTime.now(),
      );

      final device = await FlutterBluetoothPrinter.selectDevice(context);
      if (device != null) {
        await printInvoice(device, invoiceData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Factura reimpresa correctamente")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al reimprimir: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Facturas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchInvoices),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // --- FILTROS ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => selectDate(context, true),
                    child: Text(
                      'Desde: ${startDate != null ? Localization().formatDate(startDate!) : 'Todos'}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => selectDate(context, false),
                    child: Text(
                      'Hasta: ${endDate != null ? Localization().formatDate(endDate!) : 'Todos'}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Total mínimo',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      minTotal = value.isNotEmpty
                          ? double.tryParse(value)
                          : null;
                    },
                    onSubmitted: (_) {
                      currentPage = 0;
                      fetchInvoices();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Total máximo',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      maxTotal = value.isNotEmpty
                          ? double.tryParse(value)
                          : null;
                    },
                    onSubmitted: (_) {
                      currentPage = 0;
                      fetchInvoices();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // --- Filtro por cliente y vendedor ---
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: selectedCustomerId,
                    decoration: const InputDecoration(
                      labelText: "Cliente",
                      border: OutlineInputBorder(),
                    ),
                    items: customers
                        .map(
                          (c) => DropdownMenuItem<int?>(
                            value: c['id'],
                            child: Text(c['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedCustomerId = val;
                        currentPage = 0;
                      });
                      fetchInvoices();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: selectedSellerId,
                    decoration: const InputDecoration(
                      labelText: "Vendedor",
                      border: OutlineInputBorder(),
                    ),
                    items: sellers
                        .map(
                          (s) => DropdownMenuItem<int?>(
                            value: s['id'],
                            child: Text(s['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedSellerId = val;
                        currentPage = 0;
                      });
                      fetchInvoices();
                    },
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: clearFilters,
                  child: const Text('Limpiar filtros'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    final device = await FlutterBluetoothPrinter.selectDevice(
                      context,
                    );
                    if (device == null) return;
                    await printInvoiceReport(device, invoices);
                  },
                  child: const Text('Imprimir reporte'),
                ),
              ],
            ),
            // --- LISTA DE FACTURAS ---
            Expanded(
              child: invoices.isEmpty
                  ? const Center(child: Text('No hay facturas'))
                  : ListView.builder(
                      itemCount: invoices.length,
                      itemBuilder: (context, index) {
                        final inv = invoices[index];

                        return Card(
                          child: ListTile(
                            isThreeLine: true,
                            title: Text(
                              '# ${inv['id']} - Cliente ${inv['customer_id']} - ${inv['is_credit'] == 1 ? 'Crédito' : 'Contado'}',
                            ),
                            subtitle: Text(
                              'Fecha: ${Localization().formatDate(DateTime.parse(inv['date']))}\nVendedor ${inv['seller_id']}\nEstado: ${inv['is_cancelled'] == 1 ? 'Anulada' : (inv['is_paid'] == 1 ? 'Pagada' : 'Pendiente')}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "C\$ ${inv['total']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.print),
                                  tooltip: "Reimprimir",
                                  onPressed: () => reprintInvoice(inv),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/invoice_detail',
                                arguments: inv['id'] as int,
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            // --- PAGINACIÓN ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: currentPage > 0 ? previousPage : null,
                  child: const Text('Anterior'),
                ),
                Text('Página ${currentPage + 1}'),
                ElevatedButton(
                  onPressed: invoices.length == pageSize ? nextPage : null,
                  child: const Text('Siguiente'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
