import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/widgets.dart';

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
//      onCreate: create,
      singleInstance: true,
    );
    return database;
  }

//  /// Method to create the database instance
//  Future<void> create(Database database, int version) async => await SettingsDatabase().createTable(database);
}
