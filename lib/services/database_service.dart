import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';

// Imports condicionais para evitar problemas na web
import 'dart:io' if (dart.library.html) 'database_io_stub.dart' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' if (dart.library.html) 'database_web_stub.dart' as sqflite_ffi;
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init() {
    _initDatabaseFactory();
  }

  static void _initDatabaseFactory() {
    // Não inicializar na web - SQLite não funciona na web
    if (kIsWeb) return;
    
    try {
      // Verificar se é desktop (Windows, Linux, macOS)
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqflite_ffi.sqfliteFfiInit();
        databaseFactory = sqflite_ffi.databaseFactoryFfi;
      }
    } catch (e) {
      // Ignora erros - pode acontecer na web ou outras plataformas
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('clareza_diaria.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // SQLite não funciona na web
    if (kIsWeb) {
      throw UnsupportedError('SQLite não é suportado na web. Use uma plataforma mobile ou desktop.');
    }
    
    String dbPath;
    
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final directory = await getApplicationDocumentsDirectory();
        dbPath = join(directory.path, filePath);
      } else {
        dbPath = join(await getDatabasesPath(), filePath);
      }
    } catch (e) {
      // Fallback para mobile
      dbPath = join(await getDatabasesPath(), filePath);
    }

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nomeCompleto TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        senha TEXT NOT NULL,
        quemE TEXT,
        preferenciasSensoriais TEXT
      )
    ''');
  }

  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<User?> getUserByEmailAndPassword(String email, String senha) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ? AND senha = ?',
      whereArgs: [email, senha],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
