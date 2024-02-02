import 'package:mediatheque/repositories/database_service.dart';
import 'package:mediatheque/models/media_file.dart';

// SQLite stuff:
//   https://docs.flutter.dev/cookbook/persistence/sqlite
//   /> flutter pub add sqflite path
import 'package:sqflite/sqflite.dart';

/// Class to deal with the media_files table in the backend database.
class MediaFileTable {
  static const tableName = 'media_files';

  /// Get a pointer to the database and create the settings table if it doesn't exist yet.
  static Future<Database> getDatabase() async {
    final database = await DatabaseService().database;
    // https://www.sqlite.org/lang_createtable.html
    await database.execute("""CREATE TABLE IF NOT EXISTS $tableName (
      file_name TEXT NOT NULL,
      file_location TEXT NOT NULL,
      file_size INTEGER NOT NULL,
      duration_seconds INTEGER,
      last_listened_second INTEGER,
      played_to_end INTEGER,
      created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER)),
      updated_at INTEGER,
      PRIMARY KEY(file_name, file_location, file_size)
    );""");
    // Check if the table exists:
    //   SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'
    return database;
  }

  ///  Insert a record if it does not exist yet
  Future<int> create({required String fileName, required String fileLocation, required int fileSize, required int durationSeconds, int lastListenedSecond = 0, int playedToEnd = 0}) async {
    final database = await getDatabase();
    int recordID = await database.rawInsert(
      '''INSERT OR IGNORE INTO $tableName (file_name, file_location, file_size, duration_seconds, last_listened_second, played_to_end, created_at) VALUES (?,?,?,?,?,?,?)''',
      [fileName, fileLocation, fileSize, durationSeconds, lastListenedSecond, playedToEnd, DateTime.now().millisecondsSinceEpoch],
    );
    print("DB saved mediaFile: $fileName (ID: $recordID)");
    return recordID;
  }

  Future<List<MediaFile>> fetchAll() async {
    final database = await getDatabase();
    final mediaFiles = await database.rawQuery(
      '''SELECT * FROM $tableName ORDER BY file_name, file_location, file_size''',
    );
    return mediaFiles.map((mediaFile) => MediaFile.fromSqfliteDatabase(mediaFile)).toList();
  }

  Future<MediaFile> fetchByFileName({required String fileName, required String fileLocation, required int fileSize}) async {
    final database = await getDatabase();
    final mediaFiles = await database.rawQuery('''SELECT * FROM $tableName WHERE file_name = ? AND file_location = ? AND file_size = ?''', [fileName, fileLocation, fileSize]);
    return MediaFile.fromSqfliteDatabase(mediaFiles.first);
  }

  /// Update a record.
  Future<int> update({required String fileName, required String fileLocation, required int fileSize, required int durationSeconds, int lastListenedSecond = 0, int playedToEnd = 0}) async {
    final database = await getDatabase();
    return await database.update(
      tableName,
      {'file_name': fileName, 'file_location': fileLocation, 'file_size': fileSize, 'duration_seconds': durationSeconds, 'last_listened_second': lastListenedSecond, 'played_to_end': playedToEnd, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'file_name = ? AND file_location = ? AND file_size = ?',
      conflictAlgorithm: ConflictAlgorithm.rollback,
      whereArgs: [fileName, fileLocation, fileSize],
    );
  }

  /// Keep track of the last snapshot of a specific media file.
  Future<int> updateLastPlaybackLocation({required String fileName, required String fileLocation, required int fileSize, required int lastListenedSecond}) async {
    final database = await getDatabase();
    return await database.update(
      tableName,
      {'last_listened_second': lastListenedSecond, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'file_name = ? AND file_location = ? AND file_size = ?',
      conflictAlgorithm: ConflictAlgorithm.rollback,
      whereArgs: [fileName, fileLocation, fileSize],
    );
  }

  /// Update the record in the backend database to keep track of which media file we finished listening to.
  /// This is mostly useful to keep track of podcasts in a playlist so that we can circle back later and remove
  /// the ones we finished listening to.
  Future<int> updatePlayedToEnd({required String fileName, required String fileLocation, required int fileSize, required int lastListenedSecond, bool playedToEnd = true}) async {
    final database = await getDatabase();
    return await database.update(
      tableName,
      {'last_listened_second': lastListenedSecond, 'played_to_end': (playedToEnd ? 1 : 0), 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'file_name = ? AND file_location = ? AND file_size = ?',
      conflictAlgorithm: ConflictAlgorithm.rollback,
      whereArgs: [fileName, fileLocation, fileSize],
    );
  }

  /// Insert a new record or update the values if the record already exists.
  ///   https://stackoverflow.com/questions/3634984/insert-if-not-exists-else-update
  Future<void> insertOrUpdate({required String fileName, required String fileLocation, required int fileSize, required int durationSeconds, int lastListenedSecond = 0, int playedToEnd = 0}) async {
    final database = await getDatabase();
    await database.rawQuery(
        '''INSERT OR REPLACE INTO $tableName (file_name, file_location, file_size, duration_seconds, last_listened_second, played_to_end, updated_at) VALUES ('$fileName', '$fileLocation', '$fileSize', '$durationSeconds', '$lastListenedSecond', '$playedToEnd', '${DateTime.now().millisecondsSinceEpoch}')''');
  }

  /// Delete a record.
  Future<void> delete({required String fileName, required String fileLocation, required int fileSize}) async {
    final database = await getDatabase();
    await database.rawDelete('''DELETE FROM $tableName WHERE file_name = ? AND file_location = ? AND file_size''', [fileName, fileLocation, fileSize]);
  }

  /// Delete all records (clearing the app's cache).
  Future<void> deleteAll() async {
    final database = await getDatabase();
    await database.rawDelete('''DELETE FROM $tableName''');
  }
}
