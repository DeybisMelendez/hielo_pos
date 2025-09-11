import 'package:flutter/material.dart';
import 'db_helper.dart';

class SellerScreen extends StatefulWidget {
  const SellerScreen({super.key});

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  late Future<List<Map<String, dynamic>>> _sellersFuture;

  @override
  void initState() {
    super.initState();
    _loadSellers();
  }

  void _loadSellers() {
    _sellersFuture = DBHelper.getSellers();
  }

  void _showSellerForm({Map<String, dynamic>? seller}) {
    final nameController = TextEditingController(text: seller?['name'] ?? '');
    final phoneController = TextEditingController(text: seller?['phone'] ?? '');
    final emailController = TextEditingController(text: seller?['email'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(seller == null ? 'Agregar Vendedor' : 'Editar Vendedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final email = emailController.text.trim();

              if (name.isEmpty) return;

              if (seller == null) {
                await DBHelper.createSeller({
                  'name': name,
                  'phone': phone,
                  'email': email,
                });
              } else {
                await DBHelper.updateSeller(seller['id'], {
                  'name': name,
                  'phone': phone,
                  'email': email,
                });
              }

              Navigator.pop(context);
              setState(() => _loadSellers());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _deleteSeller(int id) async {
    await DBHelper.deleteSeller(id);
    setState(() => _loadSellers());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => _showSellerForm(),
          icon: const Icon(Icons.add),
          label: const Text('Agregar Vendedor'),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _sellersFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final sellers = snapshot.data!;

              if (sellers.isEmpty) {
                return const Center(child: Text('No hay vendedores'));
              }

              return ListView.builder(
                itemCount: sellers.length,
                itemBuilder: (context, index) {
                  final seller = sellers[index];
                  return ListTile(
                    title: Text(seller['name']),
                    subtitle: Text(
                      'Teléfono: ${seller['phone'] ?? '-'}\nEmail: ${seller['email'] ?? '-'}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showSellerForm(seller: seller),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteSeller(seller['id']),
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
