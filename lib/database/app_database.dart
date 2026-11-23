
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<void> initialize() async {
    if (_database != null) return;

    // Flutter Web
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
    // Windows / Linux
    else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String databasePath;

    if (kIsWeb) {
      databasePath = 'motorcycles_web.db';
    } else {
      final dbPath = await getDatabasesPath();
      databasePath = p.join(dbPath, 'motorcycles.db');
    }

    _database = await openDatabase(
      databasePath,
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createBaseTables(db);
        await _createSheetTables(db);
        await _createChassisPrefixesTable(db);
        await _createInitialDraft(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToV2(db);
        }

       if (oldVersion < 4) {
  await _createChassisPrefixesTable(db);
}
      },
    );
  }

  Future<void> _createBaseTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE traders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        traderid TEXT NOT NULL,
        traderphone TEXT,
        tradername TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bikes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chassisNumber TEXT NOT NULL,
        engineNumber TEXT,
        customerCode TEXT,
        buyerName TEXT,
        buyerAddress TEXT,
        nationalId TEXT,
        model TEXT,
        cylinder TEXT,
        bikeType TEXT,
        capacity TEXT,
        trafficUnit TEXT,
        governorate TEXT,
        subTrader TEXT,
        bikeShape TEXT,
        color TEXT,
        notes TEXT,
        electricityLetter TEXT,
        paymentMethod TEXT,
        traderId INTEGER,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (traderId) REFERENCES traders(id)
      )
    ''');
  }

  Future<void> _createSheetTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE sheets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        traderName TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        completedAt TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        exportedPath TEXT,
        recordCount INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sheet_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sheetId INTEGER NOT NULL,
        bikeId INTEGER,
        snapshotJson TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (sheetId) REFERENCES sheets(id) ON DELETE CASCADE,
        FOREIGN KEY (bikeId) REFERENCES bikes(id) ON DELETE SET NULL
      )
    ''');
  }

Future<void> _createChassisPrefixesTable(
  DatabaseExecutor db,
) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ChassisPrefixes (
      Prefix TEXT PRIMARY KEY COLLATE NOCASE,
      Capacity TEXT NOT NULL DEFAULT ''
    )
  ''');

  const prefixes = [
    'LD3PCK4JXT',
    'LD3PCK4JXS',
    'LD3PCK4JXR',
    'LD3PCM6J8T',
    'LD3PCM6J8TS',
    'VBNTGKLYXT',
    'VBNTGMLYXT',
    'VBNTGKLYXS',
    'VBNTGMLYXS',
  ];

  for (final prefix in prefixes) {
    await db.insert(
      'ChassisPrefixes',
      {
        'Prefix': prefix,
        'Capacity': '',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}

  Future<void> _createInitialDraft(DatabaseExecutor db) async {
    await db.insert('sheets', {
      'title': 'شيت جديد',
      'traderName': '',
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'draft',
      'recordCount': 0,
    });
  }

  Future<void> _upgradeToV2(Database db) async {
    final oldSheets = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name = 'sheets'",
    );

    if (oldSheets.isNotEmpty) {
      await db.execute('ALTER TABLE sheets RENAME TO legacy_sheets');
    }

    final bikeColumns = await db.rawQuery('PRAGMA table_info(bikes)');

    final existing =
        bikeColumns.map((column) => column['name'] as String).toSet();

    final additions = <String, String>{
      'customerCode': 'TEXT',
      'buyerName': 'TEXT',
      'buyerAddress': 'TEXT',
      'nationalId': 'TEXT',
      'cylinder': 'TEXT',
      'bikeType': 'TEXT',
      'capacity': 'TEXT',
      'trafficUnit': 'TEXT',
      'governorate': 'TEXT',
      'subTrader': 'TEXT',
      'bikeShape': 'TEXT',
      'color': 'TEXT',
      'notes': 'TEXT',
      'electricityLetter': 'TEXT',
      'paymentMethod': 'TEXT',
    };

    for (final entry in additions.entries) {
      if (!existing.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE bikes ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }

    await _createSheetTables(db);
    await _createInitialDraft(db);
  }

  Future<Database> get database async {
    if (_database == null) {
      await initialize();
    }

    return _database!;
  }

  // =========================
  // الشيت الحالي
  // =========================

  Future<Map<String, Object?>> getCurrentSheet() async {
    final db = await database;

    var rows = await db.query(
      'sheets',
      where: "status = 'draft'",
      orderBy: 'id DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      final id = await db.insert('sheets', {
        'title': 'شيت جديد',
        'traderName': '',
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'draft',
        'recordCount': 0,
      });

      rows = await db.query(
        'sheets',
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    return rows.first;
  }

  Future<void> updateCurrentTraderName(String name) async {
    final db = await database;
    final sheet = await getCurrentSheet();

    await db.update(
      'sheets',
      {'traderName': name.trim()},
      where: 'id = ?',
      whereArgs: [sheet['id']],
    );
  }

  // =========================
  // التجار
  // =========================

  Future<int> addTrader({
    required String traderid,
    required String tradername,
    String traderphone = '',
  }) async {
    final db = await database;

    return db.insert('traders', {
      'traderid': traderid.trim(),
      'traderphone': traderphone.trim(),
      'tradername': tradername.trim(),
    });
  }

  Future<List<Map<String, Object?>>> getTraders() async {
    final db = await database;

    return db.query(
      'traders',
      orderBy: 'tradername COLLATE NOCASE ASC',
    );
  }

  Future<int> updateTrader({
    required int id,
    required String traderid,
    required String tradername,
    String traderphone = '',
  }) async {
    final db = await database;

    return db.update(
      'traders',
      {
        'traderid': traderid.trim(),
        'traderphone': traderphone.trim(),
        'tradername': tradername.trim(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTrader(int id) async {
    final db = await database;

    await db.transaction((txn) async {
      // فصل الموتوسيكلات عن التاجر قبل حذفه.
      await txn.update(
        'bikes',
        {'traderId': null},
        where: 'traderId = ?',
        whereArgs: [id],
      );

      await txn.delete(
        'traders',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> deleteAllTraders() async {
    final db = await database;

    await db.transaction((txn) async {
      // فصل الموتوسيكلات عن جميع التجار.
      await txn.update(
        'bikes',
        {'traderId': null},
      );

      await txn.delete('traders');
    });
  }

  // =========================
  // إضافة موتوسيكل للشيت
  // =========================

  Future<int> addBikeToCurrentSheet(
    Map<String, String> fields,
  ) async {
    final db = await database;
    final sheet = await getCurrentSheet();
    final now = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      final bikeId = await txn.insert('bikes', {
        'chassisNumber': fields['chassisNumber'] ?? '',
        'engineNumber': fields['engineNumber'] ?? '',
        'customerCode': fields['customerCode'] ?? '',
        'buyerName': fields['buyerName'] ?? '',
        'buyerAddress': fields['buyerAddress'] ?? '',
        'nationalId': fields['nationalId'] ?? '',
        'model': fields['model'] ?? '',
        'cylinder': fields['cylinder'] ?? '',
        'bikeType': fields['bikeType'] ?? '',
        'capacity': fields['capacity'] ?? '',
        'trafficUnit': fields['trafficUnit'] ?? '',
        'governorate': fields['governorate'] ?? '',
        'subTrader': fields['subTrader'] ?? '',
        'bikeShape': fields['bikeShape'] ?? '',
        'color': fields['color'] ?? '',
        'notes': fields['notes'] ?? '',
        'electricityLetter': fields['electricityLetter'] ?? '',
        'paymentMethod': fields['paymentMethod'] ?? '',
        'createdAt': now,
      });

      final snapshot = <String, Object?>{
        ...fields,
        'bikeId': bikeId,
      };

      await txn.insert('sheet_items', {
        'sheetId': sheet['id'],
        'bikeId': bikeId,
        'snapshotJson': jsonEncode(snapshot),
        'createdAt': now,
      });

      final count = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM sheet_items WHERE sheetId = ?',
              [sheet['id']],
            ),
          ) ??
          0;

      await txn.update(
        'sheets',
        {'recordCount': count},
        where: 'id = ?',
        whereArgs: [sheet['id']],
      );

      return bikeId;
    });
  }

  Future<List<Map<String, Object?>>> getCurrentSheetItems() async {
    final db = await database;
    final sheet = await getCurrentSheet();

    final rows = await db.query(
      'sheet_items',
      where: 'sheetId = ?',
      whereArgs: [sheet['id']],
      orderBy: 'id ASC',
    );

    return rows.map((row) {
      return Map<String, Object?>.from(
        jsonDecode(row['snapshotJson'] as String) as Map,
      )..['itemId'] = row['id'];
    }).toList();
  }

  Future<void> removeCurrentSheetItem(int itemId) async {
    final db = await database;
    final sheet = await getCurrentSheet();

    await db.transaction((txn) async {
      await txn.delete(
        'sheet_items',
        where: 'id = ? AND sheetId = ?',
        whereArgs: [itemId, sheet['id']],
      );

      final count = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM sheet_items WHERE sheetId = ?',
              [sheet['id']],
            ),
          ) ??
          0;

      await txn.update(
        'sheets',
        {'recordCount': count},
        where: 'id = ?',
        whereArgs: [sheet['id']],
      );
    });
  }

  // =========================
  // سجل الشيتات
  // =========================

  Future<List<Map<String, Object?>>> getSheetHistory() async {
    final db = await database;

    return db.query(
      'sheets',
      where: "status != 'draft'",
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, Object?>>> getSheetSnapshotsx(
    int sheetId,
  ) async {
    final db = await database;

    final rows = await db.query(
      'sheet_items',
      where: 'sheetId = ?',
      whereArgs: [sheetId],
      orderBy: 'id ASC',
    );

    return rows
        .map(
          (row) => Map<String, Object?>.from(
            jsonDecode(row['snapshotJson'] as String) as Map,
          ),
        )
        .toList();
  }

  Future<void> completeAndStartNextSheet({
    required int sheetId,
    required String exportedPath,
    required String traderName,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      final current = await txn.query(
        'sheets',
        where: 'id = ? AND status = ?',
        whereArgs: [sheetId, 'draft'],
      );

      if (current.isEmpty) {
        throw StateError('الشيت الحالي اتقفل بالفعل.');
      }

      final count = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM sheet_items WHERE sheetId = ?',
              [sheetId],
            ),
          ) ??
          0;

      await txn.update(
        'sheets',
        {
          'title': 'شيت رقم ${sheetId.toString().padLeft(4, '0')}',
          'traderName': traderName,
          'completedAt': DateTime.now().toIso8601String(),
          'status': 'exported',
          'exportedPath': exportedPath,
          'recordCount': count,
        },
        where: 'id = ?',
        whereArgs: [sheetId],
      );

      await txn.insert('sheets', {
        'title': 'شيت جديد',
        'traderName': '',
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'draft',
        'recordCount': 0,
      });
    });
  }

  Future<void> updateReExportPath(
    int sheetId,
    String path,
  ) async {
    final db = await database;

    await db.update(
      'sheets',
      {'exportedPath': path},
      where: 'id = ?',
      whereArgs: [sheetId],
    );
  }

  // =========================
  // الموتوسيكلات
  // =========================

  Future<List<Map<String, Object?>>> getAllBikes() async {
    final db = await database;

    return db.rawQuery('''
      SELECT
        bikes.*,
        traders.tradername AS traderName
      FROM bikes
      LEFT JOIN traders ON bikes.traderId = traders.id
      ORDER BY bikes.createdAt DESC
    ''');
  }

  // =========================
  // إحصائيات لوحة التحكم
  // =========================

  Future<Map<String, Object?>> getDashboardStats() async {
    final db = await database;

    final bikeCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM bikes'),
        ) ??
        0;

    final traderCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM traders'),
        ) ??
        0;

    final sheetCount = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM sheets WHERE status = 'exported'",
          ),
        ) ??
        0;

    final current = await getCurrentSheet();

    final lastTraderRows = await db.query(
      'sheets',
      columns: ['traderName'],
      where: "status = 'exported' AND traderName != ''",
      orderBy: 'id DESC',
      limit: 1,
    );

    return {
      'bikeCount': bikeCount,
      'traderCount': traderCount,
      'sheetCount': sheetCount,
      'currentCount': current['recordCount'] ?? 0,
      'lastTrader': lastTraderRows.isEmpty
          ? 'لا يوجد'
          : lastTraderRows.first['traderName'] ?? 'لا يوجد',
    };
  }


 // جلب سجلات الشيت القديم مع رقم كل سجل.
  Future<List<Map<String, Object?>>> getSheetSnapshots(
    int sheetId,
  ) async {
    final db = await database;

    final rows = await db.query(
      'sheet_items',
      where: 'sheetId = ?',
      whereArgs: [sheetId],
      orderBy: 'id ASC',
    );

    return rows.map((row) {
      return Map<String, Object?>.from(
        jsonDecode(row['snapshotJson'] as String) as Map,
      )..['itemId'] = row['id'];
    }).toList();
  }


  // تعديل بيانات سجل داخل أي شيت محدد.
  Future<void> updateSheetItem({
    required int sheetId,
    required int itemId,
    required Map<String, String> fields,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'sheet_items',
        columns: ['snapshotJson'],
        where: 'id = ? AND sheetId = ?',
        whereArgs: [itemId, sheetId],
      );

      if (rows.isEmpty) {
        throw StateError('السجل غير موجود داخل هذا الشيت.');
      }

      final snapshot = Map<String, Object?>.from(
        jsonDecode(rows.first['snapshotJson'] as String) as Map,
      );

      snapshot.addAll(fields);

      await txn.update(
        'sheet_items',
        {'snapshotJson': jsonEncode(snapshot)},
        where: 'id = ? AND sheetId = ?',
        whereArgs: [itemId, sheetId],
      );

      final count = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM sheet_items WHERE sheetId = ?',
              [sheetId],
            ),
          ) ??
          0;

      await txn.update(
        'sheets',
        {'recordCount': count},
        where: 'id = ?',
        whereArgs: [sheetId],
      );
    });
  }

  // إضافة سجل جديد إلى شيت محدد، حتى لو كان قديمًا.
  Future<void> addSheetItem({
    required int sheetId,
    required Map<String, String> fields,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      final sheets = await txn.query(
        'sheets',
        columns: ['id'],
        where: 'id = ? AND status != ?',
        whereArgs: [sheetId, 'draft'],
      );

      if (sheets.isEmpty) {
        throw StateError('الشيت القديم غير موجود.');
      }

      await txn.insert('sheet_items', {
        'sheetId': sheetId,
        'bikeId': null,
        'snapshotJson': jsonEncode(fields),
        'createdAt': DateTime.now().toIso8601String(),
      });

      final count = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM sheet_items WHERE sheetId = ?',
              [sheetId],
            ),
          ) ??
          0;

      await txn.update(
        'sheets',
        {'recordCount': count},
        where: 'id = ?',
        whereArgs: [sheetId],
      );
    });
  }

  // حذف سجل من شيت محدد، دون المساس بالشيت الحالي.
  Future<void> removeSheetItem({
    required int sheetId,
    required int itemId,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'sheet_items',
        where: 'id = ? AND sheetId = ?',
        whereArgs: [itemId, sheetId],
      );

      final count = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM sheet_items WHERE sheetId = ?',
              [sheetId],
            ),
          ) ??
          0;

      await txn.update(
        'sheets',
        {'recordCount': count},
        where: 'id = ?',
        whereArgs: [sheetId],
      );
    });
  }

  // حفظ اسم التاجر ومسار ملف التصدير الجديد.
  Future<void> updateHistoricalSheet({
    required int sheetId,
    required String traderName,
    required String exportedPath,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      final count = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM sheet_items WHERE sheetId = ?',
              [sheetId],
            ),
          ) ??
          0;

      await txn.update(
        'sheets',
        {
          'traderName': traderName.trim(),
          'exportedPath': exportedPath,
          'recordCount': count,
        },
        where: 'id = ? AND status != ?',
        whereArgs: [sheetId, 'draft'],
      );
    });
  }



Future<List<Map<String, Object?>>> getChassisPrefixItems() async {
  final db = await database;

  return db.query(
    'ChassisPrefixes',
    orderBy: 'Prefix COLLATE NOCASE ASC',
  );
}

Future<void> saveChassisPrefix({
  required String prefix,
  required String capacity,
}) async {
  final db = await database;

  final normalizedPrefix = prefix.trim().toUpperCase();
  final normalizedCapacity = capacity.trim();

  if (normalizedPrefix.isEmpty) {
    throw ArgumentError('اكتب بادئة الشاسيه.');
  }

  if (normalizedPrefix.contains(RegExp(r'\s'))) {
    throw ArgumentError('البادئة لا يمكن أن تحتوي على مسافات.');
  }

  await db.insert(
    'ChassisPrefixes',
    {
      'Prefix': normalizedPrefix,
      'Capacity': normalizedCapacity,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<String> getCapacityForChassis(String chassisNumber) async {
  final db = await database;
  final chassis = chassisNumber.trim().toUpperCase();

  if (chassis.isEmpty) return '';

  final rows = await db.query(
    'ChassisPrefixes',
    where: '? LIKE UPPER(Prefix) || \'%\'',
    whereArgs: [chassis],
  );

  if (rows.isEmpty) return '';

  rows.sort(
    (a, b) => (b['Prefix'] as String).length.compareTo(
      (a['Prefix'] as String).length,
    ),
  );

  return '${rows.first['Capacity'] ?? ''}';
}

Future<void> updateChassisPrefix({
  required String oldPrefix,
  required String newPrefix,
  required String capacity,
}) async {
  final db = await database;

  final oldValue = oldPrefix.trim().toUpperCase();
  final newValue = newPrefix.trim().toUpperCase();
  final newCapacity = capacity.trim();

  if (newValue.isEmpty) {
    throw ArgumentError('اكتب بادئة الشاسيه.');
  }

  if (newValue.contains(RegExp(r'\s'))) {
    throw ArgumentError('البادئة لا يمكن أن تحتوي على مسافات.');
  }

  await db.transaction((txn) async {
    if (oldValue.toUpperCase() != newValue) {
      final existing = await txn.query(
        'ChassisPrefixes',
        where: 'Prefix = ?',
        whereArgs: [newValue],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        throw ArgumentError('البادئة موجودة بالفعل.');
      }
    }

    final count = await txn.update(
      'ChassisPrefixes',
      {
        'Prefix': newValue,
        'Capacity': newCapacity,
      },
      where: 'Prefix = ?',
      whereArgs: [oldValue],
    );

    if (count == 0) {
      throw StateError('البادئة غير موجودة.');
    }
  });
}

Future<void> deleteChassisPrefix(String prefix) async {
  final db = await database;

  await db.delete(
    'ChassisPrefixes',
    where: 'Prefix = ?',
    whereArgs: [prefix.trim().toUpperCase()],
  );
}



  // =========================================
  // حذف شيت قديم محدد
  // =========================================

  Future<void> deleteHistoricalSheet(int sheetId) async {
    final db = await database;

    await db.transaction((txn) async {
      final sheets = await txn.query(
        'sheets',
        columns: ['id', 'status'],
        where: 'id = ?',
        whereArgs: [sheetId],
        limit: 1,
      );

      if (sheets.isEmpty) {
        throw StateError('الشيت غير موجود.');
      }

      if (sheets.first['status'] == 'draft') {
        throw StateError('لا يمكن حذف الشيت الحالي بهذه الدالة.');
      }

      await txn.delete(
        'sheets',
        where: 'id = ?',
        whereArgs: [sheetId],
      );
    });
  }

  // =========================================
  // حذف جميع الشيتات القديمة
  // مع الاحتفاظ بالشيت الحالي
  // =========================================

  Future<int> deleteAllHistoricalSheets() async {
    final db = await database;

    return db.transaction((txn) async {
      return txn.delete(
        'sheets',
        where: "status != 'draft'",
      );
    });
  }

  // =========================================
  // حذف شيت محدد مع حماية الشيت الحالي
  // =========================================

  Future<void> deleteSheet(int sheetId) async {
    final db = await database;

    await db.transaction((txn) async {
      final sheets = await txn.query(
        'sheets',
        columns: ['id', 'status'],
        where: 'id = ?',
        whereArgs: [sheetId],
        limit: 1,
      );

      if (sheets.isEmpty) {
        throw StateError('الشيت غير موجود.');
      }

      if (sheets.first['status'] == 'draft') {
        throw StateError(
          'لا يمكن حذف الشيت الحالي. استخدم حذف الشيتات القديمة.',
        );
      }

      await txn.delete(
        'sheets',
        where: 'id = ?',
        whereArgs: [sheetId],
      );
    });
  }


}
