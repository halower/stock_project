import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/strategy.dart';
import '../models/stock.dart';

class DatabaseService {
  static const String _databaseName = 'stock_trading.db';
  static const int _databaseVersion = 1; // 简化版本号

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 创建交易记录表
    await db.execute('''
      CREATE TABLE trade_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_code TEXT NOT NULL,
        stock_name TEXT NOT NULL,
        trade_type TEXT NOT NULL,
        status TEXT NOT NULL,
        category TEXT NOT NULL,
        trade_date TEXT NOT NULL,
        create_time TEXT,
        update_time TEXT,
        market_phase TEXT,
        trend_strength TEXT,
        entry_difficulty TEXT,
        position_percentage REAL,
        position_building_method TEXT,
        price_trigger_type TEXT,
        atr_value REAL,
        atr_multiple REAL,
        risk_percentage REAL,
        invalidation_condition TEXT,
        plan_price REAL,
        plan_quantity INTEGER,
        stop_loss_price REAL,
        take_profit_price REAL,
        strategy TEXT,
        notes TEXT,
        reason TEXT,
        actual_price REAL,
        actual_quantity INTEGER,
        commission REAL,
        tax REAL,
        total_cost REAL,
        net_profit REAL,
        profit_rate REAL,
        settlement_no TEXT,
        settlement_date TEXT,
        settlement_status TEXT
      )
    ''');

    // 创建策略表
    await db.execute('''
      CREATE TABLE strategies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        entry_conditions TEXT,
        exit_conditions TEXT,
        risk_controls TEXT,
        is_active INTEGER DEFAULT 1,
        create_time TEXT NOT NULL,
        update_time TEXT
      )
    ''');

    // 创建股票表
    await db.execute('''
      CREATE TABLE stocks (
        code TEXT PRIMARY KEY,
        name TEXT,
        market TEXT,
        industry TEXT,
        board TEXT,
        area TEXT,
        ts_code TEXT,
        listing_date TEXT,
        total_shares TEXT,
        circulating_shares TEXT,
        last_updated INTEGER
      )
    ''');
  }

  // 交易记录相关方法
  Future<int> insertTradeRecord(Map<String, dynamic> record) async {
    final db = await database;
    return await db.insert('trade_records', record);
  }

  Future<int> updateTradeRecord(int id, Map<String, dynamic> record) async {
    final db = await database;
    return await db.update(
      'trade_records',
      record,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTradeRecord(int id) async {
    final db = await database;
    return await db.delete(
      'trade_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getTradeRecords() async {
    final db = await database;
    return await db.query('trade_records', orderBy: 'create_time DESC');
  }

  // 策略相关方法
  Future<int> insertStrategy(Strategy strategy) async {
    final db = await database;
    return await db.insert('strategies', strategy.toMap());
  }

  Future<int> updateStrategy(Strategy strategy) async {
    final db = await database;
    return await db.update(
      'strategies',
      strategy.toMap(),
      where: 'id = ?',
      whereArgs: [strategy.id],
    );
  }

  Future<int> deleteStrategy(int id) async {
    final db = await database;
    return await db.delete(
      'strategies',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getStrategies() async {
    final db = await database;
    return await db.query('strategies', orderBy: 'create_time DESC');
  }

  // 股票相关方法
  Future<int> insertStock(Stock stock) async {
    final db = await database;
    return await db.insert(
      'stocks',
      stock.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateStock(Stock stock) async {
    final db = await database;
    return await db.update(
      'stocks',
      stock.toMap(),
      where: 'code = ?',
      whereArgs: [stock.code],
    );
  }

  Future<int> deleteStock(String code) async {
    final db = await database;
    return await db.delete(
      'stocks',
      where: 'code = ?',
      whereArgs: [code],
    );
  }

  Future<List<Map<String, dynamic>>> getStocks() async {
    final db = await database;
    return await db.query('stocks', orderBy: 'code');
  }

  // 批量插入股票数据
  Future<void> insertStocksBatch(List<Stock> stocks) async {
    final db = await database;
    final batch = db.batch();
    
    for (final stock in stocks) {
      batch.insert(
        'stocks',
        stock.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  // 删除所有股票数据
  Future<void> clearStocks() async {
    final db = await database;
    await db.delete('stocks');
  }

  // 获取股票数量
  Future<int> getStockCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM stocks');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // 重置数据库（开发时使用）
  Future<void> resetDatabase() async {
    _database = null;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    
    if (await databaseExists(path)) {
      await deleteDatabase(path);
    }
    
    _database = await _initDatabase();
  }
}
