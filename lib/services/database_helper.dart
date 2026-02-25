import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/contact.dart';
import '../models/transaction.dart';

class DatabaseHelper {
  static DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();
  DatabaseHelper.internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hesabak.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'hesabak.db');
  }

  Future<String> getSuggestedBackupPath() async {
    final dbPath = await getDatabaseFilePath();
    final dir = dirname(dbPath);
    final base = basenameWithoutExtension(dbPath);
    return join(dir, '${base}_backup.db');
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> exportDatabase(String targetPath) async {
    final sourcePath = await getDatabaseFilePath();
    await closeDatabase();
    final targetFile = File(targetPath);
    await targetFile.parent.create(recursive: true);
    await File(sourcePath).copy(targetFile.path);
  }

  Future<void> importDatabase(String sourcePath) async {
    final destinationPath = await getDatabaseFilePath();
    await closeDatabase();
    await File(sourcePath).copy(destinationPath);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        contactId TEXT NOT NULL,
        amount REAL,
        currency TEXT,
        type TEXT NOT NULL,
        description TEXT,
        dateTime TEXT NOT NULL,
        FOREIGN KEY (contactId) REFERENCES contacts (id) ON DELETE CASCADE
      )
    ''');

    await _createSettingsTable(db);
    await _ensureDefaultCurrencyRow(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSettingsTable(db);
      await _ensureDefaultCurrencyRow(db);
    }
    if (oldVersion < 3) {
      await _migrateTransactionsToRial(db);
    }
  }

  Future<void> _migrateTransactionsToRial(Database db) async {
    // Normalize all stored amounts to rial.
    await db.execute('''
      UPDATE transactions
      SET amount = amount * 10, currency = 'rial'
      WHERE currency = 'toman'
    ''');
    await db.execute('''
      UPDATE transactions
      SET currency = 'rial'
      WHERE currency IS NULL OR currency != 'rial'
    ''');
  }

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureDefaultCurrencyRow(Database db) async {
    await db.insert(
      'settings',
      {'key': 'default_currency', 'value': Currency.toman.name},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // Contact operations
  Future<List<Contact>> getAllContacts() async {
    final db = await instance.database;
    final contactsData = await db.query('contacts');
    
    List<Contact> contacts = [];
    for (var contactMap in contactsData) {
      final transactionsData = await db.query(
        'transactions',
        where: 'contactId = ?',
        whereArgs: [contactMap['id']],
        orderBy: 'dateTime ASC',
      );
      
      final transactions = transactionsData
          .map((t) => FinancialTransaction.fromMap(t))
          .toList();
          
      contacts.add(Contact.fromMap(contactMap, transactions));
    }
    return contacts;
  }

  Future<int> insertContact(Contact contact) async {
    final db = await instance.database;
    return await db.insert('contacts', contact.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteContact(String id) async {
    final db = await instance.database;
    return await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  // Transaction operations
  Future<int> insertTransaction(FinancialTransaction transaction, String contactId) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap(contactId), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteTransaction(String id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateTransaction(FinancialTransaction transaction, String contactId) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      transaction.toMap(contactId),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  // Settings operations
  Future<Currency> getDefaultCurrency() async {
    final db = await instance.database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['default_currency'],
      limit: 1,
    );

    if (rows.isEmpty) {
      await setDefaultCurrency(Currency.toman);
      return Currency.toman;
    }

    final value = rows.first['value'] as String?;
    if (value == null) return Currency.toman;

    return Currency.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Currency.toman,
    );
  }

  Future<void> setDefaultCurrency(Currency currency) async {
    final db = await instance.database;
    await db.insert(
      'settings',
      {'key': 'default_currency', 'value': currency.name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
