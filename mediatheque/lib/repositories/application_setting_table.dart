import 'package:mediatheque/repositories/database_service.dart';
import 'package:mediatheque/models/application_setting.dart';

// SQLite stuff:
//   https://docs.flutter.dev/cookbook/persistence/sqlite
//   /> flutter pub add sqflite path
import 'package:sqflite/sqflite.dart';

/// Class to deal with the settings table in the backend database
class SettingsTable {
  static const tableName = 'settings';

  /// Get a pointer to the database and create the settings table if it doesn't exist yet.
  static Future<Database> getDatabase() async {
    final database = await DatabaseService().database;
    // https://www.sqlite.org/lang_createtable.html
    await database.execute("""CREATE TABLE IF NOT EXISTS $tableName (
      type TEXT NOT NULL,
      key TEXT NOT NULL,
      value TEXT NOT NULL,
      created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER)),
      updated_at INTEGER,
      PRIMARY KEY(type, key)
    );""");
    // Check if the table exists:
    //   SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'
    return database;
  }

  ///  Insert a record if it does not exist yet
  Future<int> create({required String type, required String key, required String value}) async {
    final database = await getDatabase();
    return await database.rawInsert(
      '''INSERT OR IGNORE INTO $tableName (type,key,value,created_at) VALUES (?,?,?,?)''',
      [type, key, value, DateTime.now().millisecondsSinceEpoch],
    );
  }

// ToDo: the next 2 methods can probably be rolled into 1 generic method:
  Future<List<ApplicationSetting>> fetchAll() async {
    final database = await getDatabase();
    final applicationSettings = await database.rawQuery(
      '''SELECT * FROM $tableName ORDER BY type, key''',
    );
    return applicationSettings.map((setting) => ApplicationSetting.fromSqfliteDatabase(setting)).toList();
  }

  Future<List<ApplicationSetting>> fetchByType(String type) async {
    final database = await getDatabase();
    final applicationSetting = await database.rawQuery('''SELECT * FROM $tableName WHERE type = ?''', [type]);
    return applicationSetting.map((setting) => ApplicationSetting.fromSqfliteDatabase(setting)).toList();
  }

  Future<ApplicationSetting> fetchByTypeAndKey(String type, String key) async {
    final database = await getDatabase();
    final applicationSetting = await database.rawQuery('''SELECT * FROM $tableName WHERE type = ? AND key = ?''', [type, key]);
    return ApplicationSetting.fromSqfliteDatabase(applicationSetting.first);
  }

  /// Update a record.
  Future<int> update({required String type, required String key, String newKey = "", required String value}) async {
    final database = await getDatabase();
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
    final database = await getDatabase();
    if (newKey == "") newKey = key;
    await database.rawQuery('''insert or replace into $tableName (type, key, value, updated_at) values ('$type', '$newKey', '$value', '${DateTime.now().millisecondsSinceEpoch}')''');
  }

  /// Delete a record.
  Future<void> delete({required String type, String key = "N/A"}) async {
    final database = await getDatabase();
    if (key == "N/A") {
      await database.rawDelete('''DELETE FROM $tableName WHERE type = ?''', [type]);
    } else {
      await database.rawDelete('''DELETE FROM $tableName WHERE type = ? AND key = ?''', [type, key]);
    }
  }
}
