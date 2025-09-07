import 'package:flutter/material.dart';
import 'invoice_screen.dart';

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
        '/invoice': (context) => const InvoiceScreen(),
        // '/products': (context) => const ProductScreen(), // 👈 ejemplo de otra vista futura
      },
    );
  }
}
