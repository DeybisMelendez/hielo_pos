// invoice_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../invoice_printer.dart';
import '../localization.dart';
import '../export_csv.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  final Widget drawer;
  const InvoiceHistoryScreen({super.key, required this.drawer});

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

  Widget _buildStatusChip(Map<String, dynamic> inv) {
    String label;
    Color color;

    if (inv['is_cancelled'] == 1) {
      label = "Anulada";
      color = Colors.red.shade400;
    } else if (inv['is_paid'] == 1) {
      label = "Pagada";
      color = Colors.green.shade400;
    } else {
      label = "Pendiente";
      color = Colors.orange.shade400;
    }

    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: const Text('Historial de Facturas'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchInvoices),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              final device = await FlutterBluetoothPrinter.selectDevice(
                context,
              );
              if (device == null) return;
              await printInvoiceReport(device, invoices);
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              try {
                await shareInvoiceReport(invoices);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Reporte compartido")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error al exportar: $e")),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // --- FILTROS ---
            ExpansionTile(
              //padding: const EdgeInsets.all(8.0),
              title: const Text("Filtros"),
              children: [
                Column(
                  children: [
                    // --- Fechas ---
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          child: ElevatedButton(
                            onPressed: () => selectDate(context, true),
                            child: Text(
                              'Desde: ${startDate != null ? Localization().formatDate(startDate!) : 'Todos'}',
                            ),
                          ),
                        ),
                        SizedBox(
                          child: ElevatedButton(
                            onPressed: () => selectDate(context, false),
                            child: Text(
                              'Hasta: ${endDate != null ? Localization().formatDate(endDate!) : 'Todos'}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // --- Totales ---
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Total mínimo',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
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
                        SizedBox(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Total máximo',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
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
                    const SizedBox(height: 12),

                    // --- Cliente y Vendedor ---
                    SizedBox(
                      child: DropdownButtonFormField<int?>(
                        isExpanded: true,
                        initialValue: selectedCustomerId,
                        decoration: const InputDecoration(
                          labelText: "Cliente",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
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
                    const SizedBox(height: 12),
                    SizedBox(
                      child: DropdownButtonFormField<int?>(
                        isExpanded: true,
                        initialValue: selectedSellerId,
                        decoration: const InputDecoration(
                          labelText: "Vendedor",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
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
                    const SizedBox(height: 12),

                    // --- Botón limpiar ---
                    ElevatedButton.icon(
                      onPressed: clearFilters,
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpiar filtros'),
                    ),
                  ],
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

                        return FutureBuilder(
                          future: Future.wait([
                            DBHelper.getCustomer(inv['customer_id']),
                            DBHelper.getSeller(inv['seller_id']),
                          ]),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const ListTile(title: Text('Cargando...'));
                            }

                            final customer = snapshot
                                .data![0]?['name']; // nombre del cliente
                            final seller = snapshot
                                .data![1]?['name']; // nombre del vendedor

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/invoice_detail',
                                    arguments: inv['id'] as int,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // --- Encabezado ---
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '#${inv['id']} - $customer',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            inv['is_credit'] == 1
                                                ? 'Crédito'
                                                : 'Contado',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: inv['is_credit'] == 1
                                                  ? Colors.blue
                                                  : Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // --- Detalles principales ---
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Fecha: ${Localization().formatDate(DateTime.parse(inv['date']))}',
                                                ),
                                                Text('Vendedor: $seller'),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            "C\$ ${inv['total']}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // --- Estado + acciones ---
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildStatusChip(
                                            inv,
                                          ), // 👈 estado con color
                                          IconButton(
                                            icon: const Icon(Icons.print),
                                            tooltip: "Reimprimir",
                                            onPressed: () =>
                                                reprintInvoice(inv),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
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
