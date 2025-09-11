import 'package:flutter/material.dart';
import 'db_helper.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  late Future<List<Map<String, dynamic>>> _customersFuture;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  void _loadCustomers() {
    _customersFuture = DBHelper.getCustomers();
  }

  void _showCustomerForm({Map<String, dynamic>? customer}) {
    final nameController = TextEditingController(text: customer?['name'] ?? '');
    final addressController = TextEditingController(
      text: customer?['address'] ?? '',
    );
    final phoneController = TextEditingController(
      text: customer?['phone'] ?? '',
    );
    final emailController = TextEditingController(
      text: customer?['email'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(customer == null ? 'Agregar Cliente' : 'Editar Cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Dirección'),
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
              final address = addressController.text.trim();
              final phone = phoneController.text.trim();
              final email = emailController.text.trim();

              if (name.isEmpty) return;

              if (customer == null) {
                await DBHelper.createCustomer({
                  'name': name,
                  'address': address,
                  'phone': phone,
                  'email': email,
                });
              } else {
                await DBHelper.updateCustomer(customer['id'], {
                  'name': name,
                  'address': address,
                  'phone': phone,
                  'email': email,
                });
              }

              Navigator.pop(context);
              setState(() => _loadCustomers());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _deleteCustomer(int id) async {
    await DBHelper.deleteCustomer(id);
    setState(() => _loadCustomers());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => _showCustomerForm(),
          icon: const Icon(Icons.add),
          label: const Text('Agregar Cliente'),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _customersFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final customers = snapshot.data!;

              if (customers.isEmpty) {
                return const Center(child: Text('No hay clientes'));
              }

              return ListView.builder(
                itemCount: customers.length,
                itemBuilder: (context, index) {
                  final customer = customers[index];
                  return ListTile(
                    title: Text(customer['name']),
                    subtitle: Text(
                      'Dirección: ${customer['address'] ?? '-'}\nTeléfono: ${customer['phone'] ?? '-'}\nEmail: ${customer['email'] ?? '-'}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              _showCustomerForm(customer: customer),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteCustomer(customer['id']),
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
