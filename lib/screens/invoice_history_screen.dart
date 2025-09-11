// invoice_history_screen.dart
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'package:intl/intl.dart';

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

  List<Map<String, dynamic>> invoices = [];
  int currentPage = 0;
  final int pageSize = 20;

  final NumberFormat currencyFormat = NumberFormat.simpleCurrency();

  @override
  void initState() {
    super.initState();
    fetchInvoices();
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
          endDate = picked;
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
                      'Desde: ${startDate != null ? DateFormat.yMd().format(startDate!) : 'Todos'}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => selectDate(context, false),
                    child: Text(
                      'Hasta: ${endDate != null ? DateFormat.yMd().format(endDate!) : 'Todos'}',
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
            Row(
              children: [
                ElevatedButton(
                  onPressed: clearFilters,
                  child: const Text('Limpiar filtros'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // --- LISTA DE FACTURAS ---
            Expanded(
              child: invoices.isEmpty
                  ? const Center(child: Text('No hay facturas'))
                  : ListView.builder(
                      itemCount: invoices.length,
                      itemBuilder: (context, index) {
                        final inv = invoices[index];

                        return FutureBuilder<Map<String, dynamic>?>(
                          future: DBHelper.getCustomer(inv['customer_id']),
                          builder: (context, snapshot) {
                            String customerName = 'Desconocido';
                            if (snapshot.connectionState ==
                                    ConnectionState.done &&
                                snapshot.hasData) {
                              customerName = snapshot.data!['name'];
                            }

                            return Card(
                              child: ListTile(
                                title: Text('# ${inv['id']} - $customerName'),
                                subtitle: Text(
                                  'Fecha: ${DateFormat.yMd().format(DateTime.parse(inv['date']))}',
                                ),
                                trailing: Text(
                                  "C\$ ${inv['total']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
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
