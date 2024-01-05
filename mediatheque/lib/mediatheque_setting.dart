// SQLLite stuff:
//   https://docs.flutter.dev/cookbook/persistence/sqlite
//   /> flutter pub add sqflite path
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/widgets.dart';

/// Class to describe a single application setting
class ApplicationSetting {
  final String type;
  final String key;
  final String value;
  final String createdAt;
  final String? updatedAt;

  static bool systemTheme = true;
  static bool darkTheme = false;
  static String defaultTab = "";

  /// Constructor
  ApplicationSetting({
    required this.type,
    required this.key,
    required this.value,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create an application setting object instance from a JSON record
  factory ApplicationSetting.fromSqfliteDatabase(Map<String, dynamic> map) => ApplicationSetting(
        type: map['type'] ?? '',
        key: map['key'] ?? '',
        value: map['value'] ?? '',
        createdAt: DateTime.fromMicrosecondsSinceEpoch(map['created_at']).toIso8601String(),
        updatedAt: map['updated_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(map['updated_at']).toIso8601String(),
      );

  String toString() {
    return "Type: $type, key: $key, value: $value";
  }
}

//-------------

/// Class to deal with the backend SQLite database
class DatabaseService {
  Database? _database;

  /// Return the full absolute path to the database
  Future<String> get fullPath async {
    const name = 'mediatheque.db';
    final path = await getDatabasesPath();
    return join(path, name);
  }

  /// Get a handle to the database instance
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initialize();
    return _database!;
  }

  /// Open the database for use.
  /// Call the create method if it doesn't exist yet.
  Future<Database> _initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    final path = await fullPath;
    print("Open database: $path");
    // Relative path on my laptop:
    //   /.dart_tool/sqflite_common_ffi/databases/ledstrips.db
    var database = await openDatabase(
      path,
      version: 1,
      onCreate: create,
      singleInstance: true,
    );
    return database;
  }

  /// Method to create the database instance
  Future<void> create(Database database, int version) async => await SettingsDatabase().createTable(database);
}

//-------------

/// Class to deal with the settings table in the backend database
class SettingsDatabase {
  final tableName = 'settings';

  /// Create the settings table
  Future<void> createTable(Database database) async {
    // https://www.sqlite.org/lang_createtable.html
    await database.execute("""CREATE TABLE IF NOT EXISTS $tableName (
      type TEXT NOT NULL,
      key TEXT NOT NULL,
      value TEXT NOT NULL,
      created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER)),
      updated_at INTEGER,
      PRIMARY KEY(type, key)
    );""");
  }

  ///  Insert a record if it does not exist yet
  Future<int> create({required String type, required String key, required String value}) async {
    final database = await DatabaseService().database;
    return await database.rawInsert(
      '''INSERT OR IGNORE INTO $tableName (type,key,value,created_at) VALUES (?,?,?,?)''',
      [type, key, value, DateTime.now().millisecondsSinceEpoch],
    );
  }

// ToDo: the next 2 methods can probably be rolled into 1 generic method:
  Future<List<ApplicationSetting>> fetchAll() async {
    final database = await DatabaseService().database;
    final ledstripSettings = await database.rawQuery(
      '''SELECT * FROM $tableName ORDER BY type, key''',
    );
    return ledstripSettings.map((setting) => ApplicationSetting.fromSqfliteDatabase(setting)).toList();
  }

  Future<List<ApplicationSetting>> fetchByType(String type) async {
    final database = await DatabaseService().database;
    final ledstripSetting = await database.rawQuery('''SELEcT * FROM $tableName WHERE type = ?''', [type]);
    return ledstripSetting.map((setting) => ApplicationSetting.fromSqfliteDatabase(setting)).toList();
  }

  Future<ApplicationSetting> fetchByTypeAndKey(String type, String key) async {
    final database = await DatabaseService().database;
    final ledstripSetting = await database.rawQuery('''SELEcT * FROM $tableName WHERE type = ? AND key = ?''', [type, key]);
    return ApplicationSetting.fromSqfliteDatabase(ledstripSetting.first);
  }

  /// Update a record.
  Future<int> update({required String type, required String key, String newKey = "", required String value}) async {
    final database = await DatabaseService().database;
    if (newKey == "") newKey = key;
    return await database.update(
      tableName,
      {'type': type, 'key': newKey, 'value': value, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'type = ? AND key = ?',
      conflictAlgorithm: ConflictAlgorithm.rollback,
      whereArgs: [type, key],
    );
  }

  /// Insert a new record or update the values if the record already exists.
  ///   https://stackoverflow.com/questions/3634984/insert-if-not-exists-else-update
  Future<void> insertOrUpdate({required String type, required String key, String newKey = "", required String value}) async {
    final database = await DatabaseService().database;
    if (newKey == "") newKey = key;
    await database.rawQuery('''insert or replace into $tableName (type, key, value, updated_at) values ('$type', '$newKey', '$value', '${DateTime.now().millisecondsSinceEpoch}')''');
  }

  /// Delete a record.
  Future<void> delete({required String type, String key = "N/A"}) async {
    final database = await DatabaseService().database;
    if (key == "N/A") {
      await database.rawDelete('''DELETE FROM $tableName WHERE type = ?''', [type]);
    } else {
      await database.rawDelete('''DELETE FROM $tableName WHERE type = ? AND key = ?''', [type, key]);
    }
  }
}
