import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// ============================================================================
/// 本地 SQLite 数据库
///
/// 一套 schema 覆盖全平台：
///   · Android / iOS / macOS  → 使用系统原生 sqflite
///   · Windows / Linux        → 使用 sqflite_common_ffi（内置 sqlite3 动态库）
///
/// 所有业务数据都会先落本地，因此断网时依然可以查看、新建、编辑，
/// 网络恢复后由 SyncService 统一补推到 Supabase。
/// ============================================================================
class AppDatabase {
  AppDatabase._internal();

  static final AppDatabase instance = AppDatabase._internal();

  static const String _dbFileName = 'doudian_shop_manager.db';
  static const int _dbVersion = 1;

  Database? _db;

  /// 表名常量，避免各处硬编码字符串写错
  static const String tableOrders = 'orders';
  static const String tableOrderItems = 'order_items';
  static const String tableProducts = 'products';
  static const String tableCustomers = 'customers';
  static const String tableAfterSales = 'after_sales';
  static const String tableProfiles = 'user_profiles';
  static const String tableKeyValue = 'app_kv';

  /// 参与 Supabase 双向同步的业务表（顺序即推送顺序，注意外键先后）
  static const List<String> syncTables = <String>[
    tableCustomers,
    tableProducts,
    tableOrders,
    tableOrderItems,
    tableAfterSales,
  ];

  String? _databasePath;

  String? get databasePath => _databasePath;

  // ---------------------------------------------------------------------------
  // 初始化：必须在 runApp 之前调用一次
  // ---------------------------------------------------------------------------
  static void initPlatformFactory() {
    // 桌面端（Windows / Linux）需要显式切换到 FFI 实现
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    // 单独放一个子目录，方便一键备份 / 清理
    final Directory appDir = Directory(p.join(dir.path, 'DoudianShopManager'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    _databasePath = p.join(appDir.path, _dbFileName);

    return openDatabase(
      _databasePath!,
      version: _dbVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        await _createTables(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        // 后续版本升级在这里追加 ALTER TABLE 语句
        // if (oldVersion < 2) { await db.execute('ALTER TABLE ...'); }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 建表
  // ---------------------------------------------------------------------------
  Future<void> _createTables(Database db) async {
    final Batch batch = db.batch();

    // ---------- 客户（买家） ----------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableCustomers (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL,
        name        TEXT NOT NULL,
        buyer_nick  TEXT,
        open_id     TEXT,
        phone       TEXT,
        address     TEXT,
        remark      TEXT,
        source      TEXT NOT NULL DEFAULT 'manual',
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL,
        is_deleted  INTEGER NOT NULL DEFAULT 0,
        sync_state  INTEGER NOT NULL DEFAULT 1
      )
    ''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_cus_user ON $tableCustomers (user_id, is_deleted)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_cus_open ON $tableCustomers (open_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_cus_phone ON $tableCustomers (phone)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_cus_sync ON $tableCustomers (sync_state)');

    // ---------- 商品档案 ----------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableProducts (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL,
        name        TEXT NOT NULL,
        spec        TEXT,
        sku_code    TEXT,
        category    TEXT,
        image_url   TEXT,
        cost_price  REAL NOT NULL DEFAULT 0,
        sale_price  REAL NOT NULL DEFAULT 0,
        stock       INTEGER NOT NULL DEFAULT 0,
        remark      TEXT,
        is_active   INTEGER NOT NULL DEFAULT 1,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL,
        is_deleted  INTEGER NOT NULL DEFAULT 0,
        sync_state  INTEGER NOT NULL DEFAULT 1
      )
    ''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_prd_user ON $tableProducts (user_id, is_deleted)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_prd_sku ON $tableProducts (sku_code)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_prd_sync ON $tableProducts (sync_state)');

    // ---------- 订单 ----------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableOrders (
        id                 TEXT PRIMARY KEY,
        user_id            TEXT NOT NULL,
        order_no           TEXT NOT NULL,
        status             TEXT NOT NULL DEFAULT 'pending_payment',
        source             TEXT NOT NULL DEFAULT 'manual',
        customer_id        TEXT,
        buyer_nick         TEXT,
        receiver_name      TEXT,
        receiver_phone     TEXT,
        receiver_address   TEXT,
        province           TEXT,
        city               TEXT,
        district           TEXT,
        product_summary    TEXT,
        item_count         INTEGER NOT NULL DEFAULT 0,
        total_amount       REAL NOT NULL DEFAULT 0,
        pay_amount         REAL NOT NULL DEFAULT 0,
        post_amount        REAL NOT NULL DEFAULT 0,
        discount_amount    REAL NOT NULL DEFAULT 0,
        logistics_code     TEXT,
        logistics_name     TEXT,
        tracking_no        TEXT,
        buyer_words        TEXT,
        seller_words       TEXT,
        remark             TEXT,
        order_time         INTEGER NOT NULL,
        pay_time           INTEGER,
        ship_time          INTEGER,
        finish_time        INTEGER,
        douyin_update_time INTEGER,
        created_at         INTEGER NOT NULL,
        updated_at         INTEGER NOT NULL,
        is_deleted         INTEGER NOT NULL DEFAULT 0,
        sync_state         INTEGER NOT NULL DEFAULT 1
      )
    ''');
    batch.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_ord_no ON $tableOrders (user_id, order_no)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_ord_user ON $tableOrders (user_id, is_deleted)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_ord_status ON $tableOrders (status)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_ord_customer ON $tableOrders (customer_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_ord_time ON $tableOrders (order_time)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_ord_sync ON $tableOrders (sync_state)');

    // ---------- 订单商品明细 ----------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableOrderItems (
        id            TEXT PRIMARY KEY,
        user_id       TEXT NOT NULL,
        order_id      TEXT NOT NULL,
        sku_order_no  TEXT,
        product_id    TEXT,
        product_name  TEXT NOT NULL,
        spec          TEXT,
        sku_id        TEXT,
        outer_sku_id  TEXT,
        image_url     TEXT,
        quantity      INTEGER NOT NULL DEFAULT 1,
        sale_price    REAL NOT NULL DEFAULT 0,
        pay_amount    REAL NOT NULL DEFAULT 0,
        cost_price    REAL NOT NULL DEFAULT 0,
        created_at    INTEGER NOT NULL,
        updated_at    INTEGER NOT NULL,
        is_deleted    INTEGER NOT NULL DEFAULT 0,
        sync_state    INTEGER NOT NULL DEFAULT 1
      )
    ''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_itm_order ON $tableOrderItems (order_id, is_deleted)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_itm_user ON $tableOrderItems (user_id, is_deleted)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_itm_sync ON $tableOrderItems (sync_state)');

    // ---------- 售后单 ----------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableAfterSales (
        id                 TEXT PRIMARY KEY,
        user_id            TEXT NOT NULL,
        order_id           TEXT,
        order_no           TEXT NOT NULL,
        after_sale_no      TEXT,
        type               TEXT NOT NULL DEFAULT 'refund_only',
        stage              TEXT NOT NULL DEFAULT 'pending',
        buyer_nick         TEXT,
        product_summary    TEXT,
        reason             TEXT,
        refund_amount      REAL NOT NULL DEFAULT 0,
        progress_note      TEXT,
        return_tracking_no TEXT,
        apply_time         INTEGER NOT NULL,
        finish_time        INTEGER,
        created_at         INTEGER NOT NULL,
        updated_at         INTEGER NOT NULL,
        is_deleted         INTEGER NOT NULL DEFAULT 0,
        sync_state         INTEGER NOT NULL DEFAULT 1
      )
    ''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_as_user ON $tableAfterSales (user_id, is_deleted)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_as_order ON $tableAfterSales (order_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_as_stage ON $tableAfterSales (stage)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_as_sync ON $tableAfterSales (sync_state)');

    // ---------- 用户资料 ----------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableProfiles (
        id            TEXT PRIMARY KEY,
        email         TEXT,
        display_name  TEXT,
        shop_name     TEXT,
        phone         TEXT,
        avatar_url    TEXT,
        updated_at    INTEGER NOT NULL,
        is_local_only INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ---------- 通用键值表（记录同步水位线等） ----------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableKeyValue (
        k TEXT PRIMARY KEY,
        v TEXT
      )
    ''');

    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // 通用键值读写
  // ---------------------------------------------------------------------------
  Future<void> setValue(String key, String value) async {
    final Database db = await database;
    await db.insert(
      tableKeyValue,
      <String, Object?>{'k': key, 'v': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getValue(String key) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      tableKeyValue,
      where: 'k = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['v'] as String?;
  }

  // ---------------------------------------------------------------------------
  // 维护操作
  // ---------------------------------------------------------------------------

  /// 清空指定账号的全部业务数据（用于「清理本地缓存」）
  Future<void> clearBusinessData(String userId) async {
    final Database db = await database;
    final Batch batch = db.batch();
    for (final String table in syncTables) {
      batch.delete(table, where: 'user_id = ?', whereArgs: <Object?>[userId]);
    }
    batch.delete(tableKeyValue,
        where: 'k LIKE ?', whereArgs: <Object?>['sync.pull.%']);
    await batch.commit(noResult: true);
  }

  /// 数据库文件体积（字节），用于设置页展示缓存大小
  Future<int> databaseSizeInBytes() async {
    if (_databasePath == null) return 0;
    final File file = File(_databasePath!);
    if (!await file.exists()) return 0;
    return file.length();
  }

  /// 整理数据库碎片
  Future<void> vacuum() async {
    final Database db = await database;
    await db.execute('VACUUM');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
