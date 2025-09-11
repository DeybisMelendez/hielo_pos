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
            price REAL NOT NULL,
          )
        ''');

        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
          )
      ''');

        await db.execute('''
          CREATE TABLE sellers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
          )
        ''');

        await db.execute('''
          CREATE TABLE invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            seller_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            total REAL NOT NULL,
            FOREIGN KEY(customer_id) REFERENCES customers(id),
            FOREIGN KEY(seller_id) REFERENCES sellers(id),
            is_cancelled INTEGER NOT NULL DEFAULT 0 CHECK (is_cancelled IN (0, 1)),
          )
        ''');

        await db.execute('''
          CREATE TABLE invoice_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            price REAL NOT NULL,
            total REAL NOT NULL,
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

  // Productos
  static Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await getDb();
    return db.query('products', orderBy: 'id ASC');
  }

  static Future<int> createProduct(Map<String, dynamic> product) async {
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

  // Facturación
  static Future<int> createInvoice({
    required int customerId,
    required int sellerId,
    required double total,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await getDb();

    // Insertar factura
    final invoiceId = await db.insert('invoices', {
      'customer_id': customerId,
      'seller_id': sellerId,
      'date': DateTime.now().toIso8601String(),
      'total': total,
    });

    // Insertar items
    for (var item in items) {
      await db.insert('invoice_items', {
        'invoice_id': invoiceId,
        'product_id': item['product_id'],
        'quantity': item['quantity'],
        'price': item['price'],
        'total': item['total'],
      });
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

  // ---------- CLIENTES ----------
  static Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await getDb();
    return db.query('customers', orderBy: 'id ASC');
  }

  static Future<Map<String, dynamic>?> getCustomer(int id) async {
    final db = await getDb();
    final result = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    } else {
      return null;
    }
  }

  static Future<int> createCustomer(Map<String, dynamic> customer) async {
    final db = await getDb();
    return db.insert('customers', customer);
  }

  static Future<int> updateCustomer(
    int id,
    Map<String, dynamic> customer,
  ) async {
    final db = await getDb();
    return db.update('customers', customer, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteCustomer(int id) async {
    final db = await getDb();
    return db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- VENDEDORES ----------
  static Future<List<Map<String, dynamic>>> getSellers() async {
    final db = await getDb();
    return db.query('sellers', orderBy: 'id ASC');
  }

  static Future<int> createSeller(Map<String, dynamic> seller) async {
    final db = await getDb();
    return db.insert('sellers', seller);
  }

  static Future<int> updateSeller(int id, Map<String, dynamic> seller) async {
    final db = await getDb();
    return db.update('sellers', seller, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteSeller(int id) async {
    final db = await getDb();
    return db.delete('sellers', where: 'id = ?', whereArgs: [id]);
  }

  static Future<Map<String, dynamic>?> getSeller(int id) async {
    final db = await getDb();
    final result = await db.query('sellers', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }
}

// Solo usarlo en desarrollo para reiniciar la DB
Future<void> resetDatabase() async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'hielo_pos.db');

  await deleteDatabase(path); // elimina la DB antigua
}
