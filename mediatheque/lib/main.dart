/*
  adb devices
  adb connect emulator-5554
  adb push ~/data/tmp/muziek 

*/

import 'dart:io';
import 'package:external_path/external_path.dart';
import 'package:mediatheque/media_files.dart';
import 'package:mediatheque/media_file.dart';
import 'package:flutter/material.dart';
// https://pub.dev/packages/permission_handler
// https://github.com/baseflow/flutter-permission-handler
//   /> flutter pub add permission_handler
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mediatheque',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Media Player'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String dir = "";
  int _counter = 0;
  MediaFiles _mediaFiles = MediaFiles();

  @override
  void initState() {
    super.initState();

    checkPermission();
    getPublicDirectoryPath();
  }

//   /// Get storage directory paths
//   /// Like internal and external (SD card) storage path
//   Future<void> getPath() async {
//     List<String> paths;
//     // getExternalStorageDirectories() will return list containing internal storage directory path
//     // And external storage (SD card) directory path (if exists)
//     paths = await ExternalPath.getExternalStorageDirectories();
//     // ex: [/storage/emulated/0, /storage/B3AE-4D28]
//     print("paths: $paths");
//   }

  // To get public storage directory path like Downloads, Picture, Movie etc.
  // Use below code
  Future<void> getPublicDirectoryPath() async {
    dir = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOWNLOADS);
    print("Downloads directory: $dir");
  }

  /// Check if we have the permission to access the filesystem.
  /*
  This code is only listing directories and is not showing any files!
  In order to have access to all files you need to go to your device settings
  Settings > Privacy > Permission manager > Files and media
  and select your app and click
  Allowed for all files
    https://github.com/dart-lang/sdk/issues/44848
    https://developer.android.com/about/versions/11/privacy/storage
    https://stackoverflow.com/questions/63213846/get-the-list-of-files-from-directory
  */
  void checkPermission() async {
    try {
      // Up to Android 12:
//      var status = await Permission.storage.request();
      // Since Android 13:
      var status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        print('Filesystem access permission is granted');
      } else if (status.isPermanentlyDenied) {
        // We don't have permission.  Open the settings page so the user can decide to allow it:
        openAppSettings();
      }
    } catch (e) {
      print('~~Filesystem permission error!!~~~>>>>>> $e');
    }
  }

  void _incrementCounter() async {
    getPublicDirectoryPath();

    List<MediaFile> files = await _mediaFiles.buildList(
        directory: dir,
        callback: (() {
          setState(() {
            // Update the UI
            print("UPDATE UI");
          });
        }));
    for (final file in files) {
      print("media file: ${file.baseFileName}");
    }

    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: _mediaFiles.files.isNotEmpty
          ? ListView.builder(
              padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
              scrollDirection: Axis.vertical,
              itemCount: _mediaFiles.files.length,
              itemBuilder: (BuildContext context, int index) {
                MediaFile song = _mediaFiles.files[index];
                return GestureDetector(
                  child: Card(
                      child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            song.baseFileName,
                            style: TextStyle(fontSize: 18),
                          ))),
                  onTap: () {
                    print("click $song");
                  },
                );
              },
            )
          : const Center(child: Text('No Files')),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
