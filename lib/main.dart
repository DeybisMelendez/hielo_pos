import 'package:flutter/material.dart';
import 'screens/create_invoice_screen.dart';
import 'screens/product_screen.dart';
import 'screens/invoice_detail_screen.dart';
import 'screens/invoice_history_screen.dart';
import 'screens/customer_screen.dart';
import 'screens/seller_screen.dart';

void main() {
  runApp(const HieloPosApp());
}

class HieloPosApp extends StatelessWidget {
  const HieloPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Widget drawer = const DrawerMenu();
    return MaterialApp(
      title: 'Hielo Motastepe POS',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/create-invoice',
      routes: {
        '/create-invoice': (context) => CreateInvoiceScreen(drawer: drawer),
        '/products': (context) => ProductScreen(drawer: drawer),
        '/invoice_detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as int;
          return InvoiceDetailScreen(invoiceId: args, drawer: drawer);
        },
        '/invoice_history': (context) => InvoiceHistoryScreen(drawer: drawer),
        '/customers': (context) => CustomerScreen(drawer: drawer),
        '/sellers': (context) => SellerScreen(drawer: drawer),
      },
    );
  }
}

class DrawerMenu extends StatelessWidget {
  const DrawerMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                SizedBox(height: 80, child: Image.asset('assets/logo.png')),
                const SizedBox(height: 10),
                const Text(
                  'Hielo Motastepe POS',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.receipt),
            title: const Text('Crear Factura'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/create-invoice');
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('Productos'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/products');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historial de Facturas'),
            onTap: () {
              Navigator.pushNamed(context, '/invoice_history');
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Clientes'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/customers');
            },
          ),
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Vendedores'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/sellers');
            },
          ),
        ],
      ),
    );
  }
}
