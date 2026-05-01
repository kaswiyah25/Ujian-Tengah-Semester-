import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/todo.dart';
import '../models/category.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'todo_database.db');
    return await openDatabase(
      path,
      version: 3, // ✅ DIUBAH: versi dinaikkan ke 3
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ✅ TAMBAHAN: Buat tabel categories terlebih dahulu
    await db.execute('''
      CREATE TABLE categories (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT NOT NULL
      )
    ''');

    // Buat tabel todos dengan kolom categoryId sebagai foreign key
    await db.execute('''
      CREATE TABLE todos (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        title       TEXT,
        description TEXT,
        createdAt   TEXT,
        isDone      INTEGER,
        deadline    TEXT,
        categoryId  INTEGER,
        FOREIGN KEY (categoryId) REFERENCES categories(id)
      )
    ''');

    // ✅ Sisipkan beberapa kategori default agar langsung bisa digunakan
    await db.insert('categories', {'name': 'Kuliah'});
    await db.insert('categories', {'name': 'Pekerjaan'});
    await db.insert('categories', {'name': 'Pribadi'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrasi dari versi 1 ke 2: tambah kolom deadline
      await db.execute('ALTER TABLE todos ADD COLUMN deadline TEXT');
    }
    if (oldVersion < 3) {
      // Migrasi dari versi 2 ke 3: buat tabel categories dan tambah categoryId
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id    INTEGER PRIMARY KEY AUTOINCREMENT,
          name  TEXT NOT NULL
        )
      ''');
      await db.execute(
        'ALTER TABLE todos ADD COLUMN categoryId INTEGER',
      );
      // Sisipkan kategori default untuk pengguna lama
      await db.insert('categories', {'name': 'Kuliah'});
      await db.insert('categories', {'name': 'Pekerjaan'});
      await db.insert('categories', {'name': 'Pribadi'});
    }
  }

  // =========================
  // CRUD TODOS
  // =========================

  Future<int> insertTodo(Todo todo) async {
    final db = await database;
    return await db.insert(
      'todos',
      todo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Todo>> getAllTodos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Todo.fromMap(maps[i]));
  }

  Future<Todo?> getTodoById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Todo.fromMap(maps.first);
  }

  Future<int> updateTodo(Todo todo) async {
    final db = await database;
    return await db.update(
      'todos',
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  Future<int> toggleTodoStatus(int id, bool isDone) async {
    final db = await database;
    return await db.update(
      'todos',
      {'isDone': isDone ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTodo(int id) async {
    final db = await database;
    return await db.delete(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearCompletedTodos() async {
    final db = await database;
    return await db.delete(
      'todos',
      where: 'isDone = ?',
      whereArgs: [1],
    );
  }

  // Filter + Pencarian + Filter Kategori dalam satu metode
  // filterStatus  : 'all' | 'active' | 'done'
  // keyword       : pencarian pada kolom title dengan LIKE
  // categoryId    : null = semua kategori, angka = kategori tertentu
  Future<List<Todo>> getTodosFiltered({
    String filterStatus = 'all',
    String keyword = '',
    int? categoryId,
  }) async {
    final db = await database;

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    // Filter status
    if (filterStatus == 'active') {
      whereClauses.add('isDone = ?');
      whereArgs.add(0);
    } else if (filterStatus == 'done') {
      whereClauses.add('isDone = ?');
      whereArgs.add(1);
    }

    // Pencarian kata kunci
    if (keyword.trim().isNotEmpty) {
      whereClauses.add('title LIKE ?');
      whereArgs.add('%${keyword.trim()}%');
    }

    // ✅ TAMBAHAN: Filter berdasarkan kategori
    if (categoryId != null) {
      whereClauses.add('categoryId = ?');
      whereArgs.add(categoryId);
    }

    final String? whereString =
        whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) => Todo.fromMap(maps[i]));
  }

  // =========================
  // ✅ BARU: CRUD CATEGORIES
  // =========================

  // Menambahkan kategori baru
  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // Membaca semua kategori
  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  // Membaca satu kategori berdasarkan id
  Future<Category?> getCategoryById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  // Memperbarui nama kategori
  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  // Menghapus kategori berdasarkan id
  // Tugas yang terhubung akan memiliki categoryId = NULL setelah dihapus
  Future<int> deleteCategory(int id) async {
    final db = await database;

    // Set categoryId tugas yang terhubung menjadi NULL terlebih dahulu
    await db.update(
      'todos',
      {'categoryId': null},
      where: 'categoryId = ?',
      whereArgs: [id],
    );

    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}