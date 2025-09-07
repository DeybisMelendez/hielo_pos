import 'package:flutter/material.dart';
import 'invoice_screen.dart';
import 'product_screen.dart';

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
            const BaseScreen(child: InvoiceScreen(), title: 'Facturas'),
        '/products': (context) =>
            const BaseScreen(child: ProductScreen(), title: 'Productos'),
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
          ],
        ),
      ),
      body: child,
    );
  }
}
