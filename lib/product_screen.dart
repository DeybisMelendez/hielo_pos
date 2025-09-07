import 'package:flutter/material.dart';
import 'db_helper.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    _productsFuture = DBHelper.getProducts();
  }

  void _showProductForm({Map<String, dynamic>? product}) {
    final nameController = TextEditingController(text: product?['name'] ?? '');
    final priceController = TextEditingController(
      text: product != null ? (product['price'] as num).toString() : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product == null ? 'Agregar Producto' : 'Editar Producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Precio'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text.trim()) ?? 0;

              if (name.isEmpty || price <= 0) return;

              if (product == null) {
                await DBHelper.insertProduct({'name': name, 'price': price});
              } else {
                await DBHelper.updateProduct(product['id'], {
                  'name': name,
                  'price': price,
                });
              }

              Navigator.pop(context);
              setState(() => _loadProducts());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(int id) async {
    await DBHelper.deleteProduct(id);
    setState(() => _loadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => _showProductForm(),
          icon: const Icon(Icons.add),
          label: const Text('Agregar Producto'),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final products = snapshot.data!;

              if (products.isEmpty) {
                return const Center(child: Text('No hay productos'));
              }

              return ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ListTile(
                    title: Text(product['name']),
                    subtitle: Text('Precio: \$${product['price']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showProductForm(product: product),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteProduct(product['id']),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
