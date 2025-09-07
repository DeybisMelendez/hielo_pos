import 'package:flutter/material.dart';
import 'invoice_screen.dart';
import 'product_screen.dart';
import 'invoice_history_screen.dart';

void main() {
  runApp(const HieloPosApp());
}

class HieloPosApp extends StatelessWidget {
  const HieloPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hielo POS',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/invoice',
      routes: {
        '/invoice': (context) =>
            const BaseScreen(title: 'Facturas', child: InvoiceScreen()),
        '/products': (context) =>
            const BaseScreen(title: 'Productos', child: ProductScreen()),
        '/invoice_history': (context) => const InvoiceHistoryScreen(),
      },
    );
  }
}

/// Scaffold base con Drawer para navegación
class BaseScreen extends StatelessWidget {
  final Widget child;
  final String title;

  const BaseScreen({super.key, required this.child, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Hielo POS',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Facturas'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/invoice');
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
          ],
        ),
      ),
      body: child,
    );
  }
}
