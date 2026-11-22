import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/utils.dart';
import '../models/models.dart';

/// Naik setiap kali data berubah, supaya layar yang terbuka memuat ulang.
final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  late final Database _db;

  static const defaultQrisStatic =
      '00020101021126570011ID.DANA.WWW011893600915303722287402090372228740303UMI51440014ID.CO.QRIS.WWW0215ID10266448558880303UMI5204899953033605802ID5923Kresna Laundry, Service6014Bandar Lampung61053512263049EC3';

  Future<void> init() async {
    final path = p.join(await getDatabasesPath(), 'kresna_laundry.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    // Jika kode QRIS belum pernah diatur, otomatis isi QRIS resmi Kresna Laundry.
    final qris = await getSetting('qris_static');
    if (qris.isEmpty) {
      await _db.insert(
        'settings',
        {'key': 'qris_static', 'value': defaultQrisStatic},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  void _bump() => dataVersion.value++;

  Future<void> _seedServicesAndTariffs(DatabaseExecutor db) async {
    // 3 pilihan waktu pengerjaan: Reguler (3 hari), One Day (1 hari), Quick Express (3 jam)
    final pReguler = await db.insert('packages', {
      'name': 'Reguler',
      'estimate_hours': 72,
      'active': 1,
    });
    final pOneDay = await db.insert('packages', {
      'name': 'One Day',
      'estimate_hours': 24,
      'active': 1,
    });
    final pExpress = await db.insert('packages', {
      'name': 'Quick Express',
      'estimate_hours': 3,
      'active': 1,
    });

    final pkgIds = [pReguler, pOneDay, pExpress];

    // 3 jenis layanan (semua per kg) + daftar tarif awal:
    // [code, name, description, harga Reguler, harga One Day, harga Quick Express]
    final seed = <List<Object>>[
      [
        'CSJ',
        'Cuci Saja',
        'Pakaian dicuci, dikeringkan, dan dilipat. Tidak termasuk menyetrika.',
        6000,
        9000,
        15000,
      ],
      [
        'CGS',
        'Cuci + Gosok',
        'Pakaian dicuci, dikeringkan, disetrika, dan dilipat. Layanan lengkap.',
        9000,
        15000,
        25000,
      ],
      [
        'GSJ',
        'Gosok Saja',
        'Pakaian hanya disetrika dan dilipat. Tidak termasuk pencucian.',
        6000,
        12000,
        18000,
      ],
    ];

    for (final s in seed) {
      final itemId = await db.insert('item_types', {
        'code': s[0],
        'name': s[1],
        'kind': 'kiloan',
        'description': s[2],
        'active': 1,
      });
      for (var i = 0; i < pkgIds.length; i++) {
        await db.insert('item_prices', {
          'item_type_id': itemId,
          'package_id': pkgIds[i],
          'price': (s[3 + i] as int).toDouble(),
        });
      }
    }
  }

  Future<void> _onCreate(Database db, int v) async {
    await db.execute('''
      CREATE TABLE packages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        estimate_hours INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      )''');
    await db.execute('''
      CREATE TABLE item_types(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        active INTEGER NOT NULL DEFAULT 1
      )''');
    await db.execute('''
      CREATE TABLE item_prices(
        item_type_id INTEGER NOT NULL,
        package_id INTEGER NOT NULL,
        price REAL NOT NULL,
        PRIMARY KEY(item_type_id, package_id)
      )''');
    await db.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        customer_name TEXT NOT NULL,
        phone TEXT,
        date TEXT NOT NULL,
        item_type_id INTEGER NOT NULL,
        item_code TEXT NOT NULL,
        item_name TEXT NOT NULL,
        kind TEXT NOT NULL,
        qty REAL NOT NULL,
        package_id INTEGER NOT NULL,
        package_name TEXT NOT NULL,
        estimate_hours INTEGER NOT NULL,
        estimated_done_at TEXT,
        unit_price REAL NOT NULL,
        total REAL NOT NULL,
        notes TEXT,
        work_status INTEGER NOT NULL DEFAULT 0,
        pay_status INTEGER NOT NULL DEFAULT 0,
        pay_method TEXT,
        paid_at TEXT
      )''');
    await db.execute(
        'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');

    await _seedServicesAndTariffs(db);

    await db.insert('settings', {'key': 'store_name', 'value': 'Kresna Laundry'});
    await db.insert('settings', {'key': 'store_address', 'value': ''});
    await db.insert('settings', {'key': 'store_phone', 'value': ''});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE packages ADD COLUMN active INTEGER NOT NULL DEFAULT 1');
      await db.execute(
          "ALTER TABLE item_types ADD COLUMN description TEXT NOT NULL DEFAULT ''");
      await db.execute(
          'ALTER TABLE item_types ADD COLUMN active INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE orders ADD COLUMN estimated_done_at TEXT');

      // Ganti master paket & layanan lama ke sistem baru tanpa mengubah tabel orders.
      await db.delete('item_prices');
      await db.delete('item_types');
      await db.delete('packages');
      await _seedServicesAndTariffs(db);
    }
  }

  // ---------- Pengaturan ----------
  Future<String> getSetting(String key, [String def = '']) async {
    final r = await _db.query('settings', where: 'key=?', whereArgs: [key]);
    if (r.isEmpty) return def;
    return (r.first['value'] as String?) ?? def;
  }

  Future<void> setSetting(String key, String value) async {
    await _db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _bump();
  }

  // ---------- Waktu pengerjaan (packages) ----------
  Future<List<LaundryPackage>> getPackages({bool activeOnly = false}) async {
    final r = await _db.query(
      'packages',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'id',
    );
    return r.map(LaundryPackage.fromMap).toList();
  }

  Future<void> updatePackage(int id, {int? estimateHours, bool? active}) async {
    final values = <String, Object?>{};
    if (estimateHours != null) values['estimate_hours'] = estimateHours;
    if (active != null) values['active'] = active ? 1 : 0;
    if (values.isEmpty) return;
    await _db.update('packages', values, where: 'id=?', whereArgs: [id]);
    _bump();
  }

  // ---------- Jenis layanan & tarif ----------
  Future<List<ItemType>> getItemTypes({bool activeOnly = false}) async {
    final r = await _db.query(
      'item_types',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'id',
    );
    return r.map(ItemType.fromMap).toList();
  }

  /// itemTypeId -> (packageId -> harga/kg)
  Future<Map<int, Map<int, double>>> getPrices() async {
    final r = await _db.query('item_prices');
    final out = <int, Map<int, double>>{};
    for (final m in r) {
      out.putIfAbsent(m['item_type_id'] as int, () => {})[
          m['package_id'] as int] = (m['price'] as num).toDouble();
    }
    return out;
  }

  /// Melempar exception jika kode sudah dipakai.
  Future<void> saveItemType({
    int? id,
    required String code,
    required String name,
    required bool isKiloan,
    String description = '',
    bool active = true,
    required Map<int, double> prices,
  }) async {
    await _db.transaction((txn) async {
      var itemId = id;
      if (itemId == null) {
        itemId = await txn.insert('item_types', {
          'code': code.toUpperCase(),
          'name': name,
          'kind': isKiloan ? 'kiloan' : 'satuan',
          'description': description,
          'active': active ? 1 : 0,
        });
      } else {
        await txn.update(
          'item_types',
          {
            'name': name,
            'description': description,
            'active': active ? 1 : 0,
          },
          where: 'id=?',
          whereArgs: [itemId],
        );
      }
      for (final e in prices.entries) {
        await txn.insert(
            'item_prices',
            {'item_type_id': itemId, 'package_id': e.key, 'price': e.value},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    _bump();
  }

  Future<void> setItemTypeActive(int id, bool active) async {
    await _db.update(
      'item_types',
      {'active': active ? 1 : 0},
      where: 'id=?',
      whereArgs: [id],
    );
    _bump();
  }

  Future<void> deleteItemType(int id) async {
    await _db.transaction((txn) async {
      await txn.delete('item_prices',
          where: 'item_type_id=?', whereArgs: [id]);
      await txn.delete('item_types', where: 'id=?', whereArgs: [id]);
    });
    _bump();
  }

  // ---------- Pesanan ----------
  Future<String> nextCode(String itemCode, DateTime date) async {
    final prefix = '$itemCode-${DateFormat('yyMMdd').format(date)}-';
    final r = await _db.rawQuery(
      'SELECT MAX(CAST(substr(code, ?) AS INTEGER)) AS m FROM orders WHERE code LIKE ?',
      [prefix.length + 1, '$prefix%'],
    );
    final m = (r.first['m'] as int?) ?? 0;
    return '$prefix${(m + 1).toString().padLeft(3, '0')}';
  }

  Future<int> insertOrder(LaundryOrder o) async {
    final id = await _db.insert('orders', o.toMap());
    _bump();
    return id;
  }

  Future<void> updateOrder(LaundryOrder o) async {
    await _db.update('orders', o.toMap(), where: 'id=?', whereArgs: [o.id]);
    _bump();
  }

  Future<void> deleteOrder(int id) async {
    await _db.delete('orders', where: 'id=?', whereArgs: [id]);
    _bump();
  }

  Future<LaundryOrder?> getOrder(int id) async {
    final r = await _db.query('orders', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : LaundryOrder.fromMap(r.first);
  }

  Future<List<LaundryOrder>> getOrders({
    String? query,
    DateTime? from,
    DateTime? to,
    int? work,
    int? pay,
    String? phone,
    String? customerName,
    int? limit,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (query != null && query.trim().isNotEmpty) {
      where.add('(customer_name LIKE ? OR code LIKE ?)');
      args..add('%${query.trim()}%')..add('%${query.trim()}%');
    }
    if (from != null) {
      where.add('date >= ?');
      args.add(isoDate(from));
    }
    if (to != null) {
      where.add('date <= ?');
      args.add(isoDate(to));
    }
    if (work != null) {
      where.add('work_status = ?');
      args.add(work);
    }
    if (pay != null) {
      where.add('pay_status = ?');
      args.add(pay);
    }
    if (phone != null) {
      where.add("IFNULL(phone,'') = ?");
      args.add(phone);
    }
    if (customerName != null) {
      where.add('customer_name = ?');
      args.add(customerName);
    }
    final r = await _db.query(
      'orders',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
    return r.map(LaundryOrder.fromMap).toList();
  }

  Future<void> setWorkStatus(int id, int status) async {
    await _db.update('orders', {'work_status': status},
        where: 'id=?', whereArgs: [id]);
    _bump();
  }

  /// Hanya dipanggil setelah admin mengonfirmasi pembayaran.
  Future<void> markPaid(int id, String method, DateTime paidAt) async {
    await _db.update(
        'orders',
        {
          'pay_status': 1,
          'pay_method': method,
          'paid_at': paidAt.toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [id]);
    _bump();
  }

  Future<void> markUnpaid(int id) async {
    await _db.update('orders',
        {'pay_status': 0, 'pay_method': null, 'paid_at': null},
        where: 'id=?', whereArgs: [id]);
    _bump();
  }

  // ---------- Dashboard / pelanggan / laporan ----------
  Future<Map<String, num>> dashboardStats() async {
    final r = await _db.rawQuery('''
      SELECT COUNT(*) AS total,
        COALESCE(SUM(work_status = 1), 0) AS proses,
        COALESCE(SUM(work_status >= 2), 0) AS selesai,
        COALESCE(SUM(pay_status = 0), 0) AS unpaid,
        COALESCE(SUM(CASE WHEN pay_status = 1 THEN total ELSE 0 END), 0) AS revenue
      FROM orders''');
    final m = r.first;
    return {
      'total': m['total'] as num,
      'proses': m['proses'] as num,
      'selesai': m['selesai'] as num,
      'unpaid': m['unpaid'] as num,
      'revenue': m['revenue'] as num,
    };
  }

  Future<List<Map<String, Object?>>> getCustomers({String? query}) async {
    final hasQ = query != null && query.trim().isNotEmpty;
    return _db.rawQuery('''
      SELECT customer_name, IFNULL(phone,'') AS phone, COUNT(*) AS cnt,
             SUM(total) AS spent, MAX(date) AS last_date
      FROM orders
      ${hasQ ? "WHERE customer_name LIKE ? OR phone LIKE ?" : ""}
      GROUP BY customer_name, IFNULL(phone,'')
      ORDER BY MAX(id) DESC''',
        hasQ ? ['%${query.trim()}%', '%${query.trim()}%'] : []);
  }

  /// Transaksi, selesai, dan belum dibayar dihitung berdasarkan tanggal pesanan.
  /// Pendapatan dihitung berdasarkan tanggal pembayaran.
  Future<Map<String, Object>> report(DateTime from, DateTime to) async {
    final f = isoDate(from);
    final t = isoDate(to);
    final tx = await _db.rawQuery('''
      SELECT COUNT(*) AS total,
        COALESCE(SUM(work_status >= 2), 0) AS selesai,
        COALESCE(SUM(pay_status = 0), 0) AS unpaid
      FROM orders WHERE date >= ? AND date <= ?''', [f, t]);
    final paidFrom = DateTime(from.year, from.month, from.day).toIso8601String();
    final paidTo = DateTime(to.year, to.month, to.day)
        .add(const Duration(days: 1))
        .toIso8601String();
    final byMethod = await _db.rawQuery('''
      SELECT pay_method AS m, COUNT(*) AS c, SUM(total) AS s FROM orders
      WHERE pay_status = 1 AND paid_at >= ? AND paid_at < ?
      GROUP BY pay_method''', [paidFrom, paidTo]);
    final daily = await _db.rawQuery('''
      SELECT substr(paid_at, 1, 10) AS d, COUNT(*) AS c, SUM(total) AS s FROM orders
      WHERE pay_status = 1 AND paid_at >= ? AND paid_at < ?
      GROUP BY substr(paid_at, 1, 10) ORDER BY d DESC''', [paidFrom, paidTo]);

    double cash = 0, qris = 0;
    for (final r in byMethod) {
      final s = (r['s'] as num?)?.toDouble() ?? 0;
      if (r['m'] == 'QRIS') {
        qris += s;
      } else {
        cash += s;
      }
    }
    return {
      'total': tx.first['total'] as num,
      'selesai': tx.first['selesai'] as num,
      'unpaid': tx.first['unpaid'] as num,
      'cash': cash,
      'qris': qris,
      'revenue': cash + qris,
      'daily': daily,
    };
  }

  // ---------- Backup & Restore ----------
  Future<Map<String, Object?>> exportBackupMap() async {
    return {
      'app': 'kresna_laundry',
      'schema_version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'packages': await _db.query('packages', orderBy: 'id'),
      'item_types': await _db.query('item_types', orderBy: 'id'),
      'item_prices': await _db.query('item_prices'),
      'orders': await _db.query('orders', orderBy: 'id'),
      'settings': await _db.query('settings'),
    };
  }

  /// Memulihkan seluruh database dari map hasil JSON backup.
  /// Mengembalikan jumlah pesanan yang berhasil dipulihkan.
  Future<int> importBackupMap(Map<String, dynamic> data) async {
    if (data['app'] != 'kresna_laundry') {
      throw const FormatException('File bukan cadangan Kresna Laundry.');
    }
    final packages = (data['packages'] as List?)?.cast<Map>() ?? const [];
    final itemTypes = (data['item_types'] as List?)?.cast<Map>() ?? const [];
    final itemPrices = (data['item_prices'] as List?)?.cast<Map>() ?? const [];
    final orders = (data['orders'] as List?)?.cast<Map>() ?? const [];
    final settings = (data['settings'] as List?)?.cast<Map>() ?? const [];

    await _db.transaction((txn) async {
      await txn.delete('orders');
      await txn.delete('item_prices');
      await txn.delete('item_types');
      await txn.delete('packages');
      await txn.delete('settings');

      for (final r in packages) {
        await txn.insert('packages', Map<String, Object?>.from(r),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final r in itemTypes) {
        await txn.insert('item_types', Map<String, Object?>.from(r),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final r in itemPrices) {
        await txn.insert('item_prices', Map<String, Object?>.from(r),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final r in orders) {
        await txn.insert('orders', Map<String, Object?>.from(r),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final r in settings) {
        await txn.insert('settings', Map<String, Object?>.from(r),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    _bump();
    return orders.length;
  }
}
