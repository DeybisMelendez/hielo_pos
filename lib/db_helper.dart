import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> _initDb() async {
    await resetDatabase(); // solo en desarrollo
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hielo_pos.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            price REAL NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            address TEXT,
            phone TEXT,
            email TEXT
          )
      ''');

        await db.execute('''
          CREATE TABLE sellers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER,
            seller_id INTEGER,
            date TEXT,
            total REAL,
            FOREIGN KEY(customer_id) REFERENCES customers(id),
            FOREIGN KEY(seller_id) REFERENCES sellers(id)
          )
        ''');

        await db.execute('''
          CREATE TABLE invoice_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER,
            invoice_id INTEGER,
            quantity INTEGER,
            price REAL,
            total REAL,
            FOREIGN KEY(product_id) REFERENCES products(id),
            FOREIGN KEY(invoice_id) REFERENCES invoices(id)
          )
        ''');

        await db.insert('products', {'name': 'Hielo 10 lb', 'price': 50});
        await db.insert('products', {'name': 'Hielo 20 lb', 'price': 90});
        await db.insert("customers", {'name': 'Cliente Genérico'});
        await db.insert("sellers", {'name': 'Deybis Melendez'});
      },
    );
  }

  static Future<Database> getDb() async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  // ---------- PRODUCTOS ----------
  static Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await getDb();
    return db.query('products', orderBy: 'id ASC');
  }

  static Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await getDb();
    return db.insert('products', product);
  }

  static Future<int> updateProduct(int id, Map<String, dynamic> product) async {
    final db = await getDb();
    return db.update('products', product, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteProduct(int id) async {
    final db = await getDb();
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- VENTAS (Facturas) ----------
  static Future<int> createInvoice({
    int? customerId,
    int? sellerId,
    required List<Map<String, dynamic>> items, // [{product_id, quantity}]
  }) async {
    final db = await getDb();
    final dateStr = DateTime.now().toIso8601String();

    // Calcular total de la factura
    double totalInvoice = 0;
    List<Map<String, dynamic>> invoiceItems = [];

    for (var item in items) {
      final productId = item['product_id'] as int;
      final quantity = item['quantity'] as int;

      final products = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (products.isEmpty) {
        throw Exception('Producto no encontrado: $productId');
      }

      final product = products.first;
      final double unitPrice = (product['price'] as num).toDouble();
      final double total = unitPrice * quantity;

      totalInvoice += total;

      invoiceItems.add({
        'product_id': productId,
        'quantity': quantity,
        'price': unitPrice,
        'total': total,
      });
    }

    // Insertar la factura
    final invoiceId = await db.insert('invoices', {
      'customer_id': customerId,
      'seller_id': sellerId,
      'date': dateStr,
      'total': totalInvoice,
    });

    // Insertar los items de la factura
    for (var item in invoiceItems) {
      await db.insert('invoice_items', {...item, 'invoice_id': invoiceId});
    }

    return invoiceId;
  }

  static Future<List<Map<String, dynamic>>> getInvoices() async {
    final db = await getDb();
    return db.query('invoices', orderBy: 'id DESC');
  }

  static Future<List<Map<String, dynamic>>> getInvoiceItems(
    int invoiceId,
  ) async {
    final db = await getDb();
    return db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
  }

  static Future<void> clearInvoices() async {
    final db = await getDb();
    await db.delete('invoice_items');
    await db.delete('invoices');
  }

  static Future<List<Map<String, dynamic>>> getInvoicesFiltered({
    DateTime? startDate,
    DateTime? endDate,
    double? minTotal,
    double? maxTotal,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await getDb();
    String where = '';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      where += '${where.isEmpty ? '' : ' AND '}date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where += '${where.isEmpty ? '' : ' AND '}date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    if (minTotal != null) {
      where += '${where.isEmpty ? '' : ' AND '}total >= ?';
      whereArgs.add(minTotal);
    }

    if (maxTotal != null) {
      where += '${where.isEmpty ? '' : ' AND '}total <= ?';
      whereArgs.add(maxTotal);
    }

    return db.query(
      'invoices',
      where: where.isEmpty ? null : where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );
  }

  static Future<Map<String, dynamic>?> getCustomerById(int id) async {
    final db = await getDb();
    final result = await db.query(
      'customers', // nombre de tu tabla de clientes
      where: 'id = ?', // condición
      whereArgs: [id], // argumentos para la condición
      limit: 1, // solo queremos un registro
    );

    if (result.isNotEmpty) {
      return result.first; // devuelve el primer registro encontrado
    } else {
      return null; // si no existe, devuelve null
    }
  }
}

// Solo usarlo en desarrollo para reiniciar la DB
Future<void> resetDatabase() async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'hielo_pos.db');

  await deleteDatabase(path); // elimina la DB antigua
}
