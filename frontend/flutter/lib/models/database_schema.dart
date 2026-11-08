import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chatbot.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create chat_messages table
    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY,
        customer_id INTEGER NOT NULL,
        message_type TEXT NOT NULL, -- 'text', 'image', 'audio', 'video'
        content TEXT NOT NULL, -- For text messages or file paths for media
        is_from_user BOOLEAN NOT NULL,
        created_at TIMESTAMP NOT NULL
      )
    ''');
  }

  // Helper methods for database operations
  Future<int> insertChatMessage(Map<String, dynamic> message) async {
    final db = await database;
    return await db.insert('chat_messages', message);
  }


  Future<List<Map<String, dynamic>>> getChatHistory(int customer_id, int limit) async {
    final db = await database;
    return await db.query(
      'chat_messages',
      where: 'customer_id = ?',
      whereArgs: [customer_id],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }
} 