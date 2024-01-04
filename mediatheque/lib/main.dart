/*
  flutter build apk --release

  adb devices
  adb connect emulator-5554
  adb push ~/data/tmp/muziek 

*/

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mediatheque/mediatheque_setting.dart';
import 'package:mediatheque/media_files.dart';
import 'package:mediatheque/media_file.dart';
import 'package:external_path/external_path.dart';
import 'package:path/path.dart';
// https://pub.dev/packages/permission_handler
// https://github.com/baseflow/flutter-permission-handler
//   /> flutter pub add permission_handler
import 'package:permission_handler/permission_handler.dart';
// Used to dynamically restart the app:
//   https://pub.dev/packages/flutter_phoenix
//   /> flutter pub add flutter_phoenix
import 'package:flutter_phoenix/flutter_phoenix.dart';
// Used to select a directory:
//   https://pub.dev/packages/filesystem_picker
//   /> flutter pub add filesystem_picker
import 'package:filesystem_picker/filesystem_picker.dart';

void main() {
  runApp(
      // Wrapping the app in a Phoenix widget that we can use to hot restart when needed.
      // (the Phoenix widget basically generates a new 'key' on itself, invalidating the
      // UI and regenerating everything)
      Phoenix(
    child: MediathequeApp(),
  ));
}

//-------------

class Menu {
  static const String SetDirectory = 'Change directory';
  static const String ChangeTheme = 'Toggle Theme';
  static const String Refresh = 'Refresh files';
  static const String Exit = 'Exit';
  static const List<String> menuItems = <String>[SetDirectory, ChangeTheme, Refresh, Exit];
}

//-------------

class MediathequeApp extends StatelessWidget {
  final title = "Mediatheque";

  /// Constructor
  MediathequeApp() {
    super.key;
  }

  /// This widget is the root of the application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      themeMode: ApplicationSetting.systemTheme ? ThemeMode.system : (ApplicationSetting.darkTheme ? ThemeMode.dark : ThemeMode.light),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MediathequeHomePage(title: title, context: context),
    );
  }
}

//-------------

class MediathequeHomePage extends StatefulWidget {
  const MediathequeHomePage({super.key, required this.title, required this.context});
  final String title;
  final BuildContext context;

  @override
  State<MediathequeHomePage> createState() => _MediathequeHomePageState();
}

//-------------

class _MediathequeHomePageState extends State<MediathequeHomePage> with TickerProviderStateMixin {
  final settingsDatabase = SettingsDatabase();
  MediaFiles _mediaFiles = MediaFiles();
  late TabController tabController;
  List<String> tabNames = ["Media", "Logs"];
  int currentTab = 0;
  String statusText = "No Files...";
  String mediaDirectory = "";

  @override
  void initState() {
    super.initState();

    checkPermission();
    loadSettings();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  void loadSettings() {
    setState(() {
      settingsDatabase.fetchAll().then((settings) {
        for (var setting in settings) {
          switch (setting.type) {
            // Process app settings:
            case "setting":
              switch (setting.key) {
                // Process media directory path:
                case "media_directory":
                  mediaDirectory = setting.value;
                // Process display theme setting:
                case "theme":
                  setTheme(themeName: setting.value);
                  break;
                // Process default tab setting:
                case "default_tab":
                  ApplicationSetting.defaultTab = setting.value;
                  statusText += "\nSelect tab: ${ApplicationSetting.defaultTab}";
                  break;
              }
              break;
          }
        }
        // Set the default directory if not found in the settings:
        if (mediaDirectory.isEmpty) {
//          getPublicDirectoryPath();
          mediaDirectory = "/storage/emulated/0/Documents";
        }
        // Get a file listing and update the UI:
        refreshList();
      });
    });
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
    mediaDirectory = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOWNLOADS);
    print("Downloads directory: $mediaDirectory");
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
        statusText = 'Filesystem access permission is granted';
      } else if (status.isPermanentlyDenied) {
        // We don't have permission.  Open the settings page so the user can decide to allow it:
        openAppSettings();
      }
    } catch (e) {
      print('~~Filesystem permission error!!~~~>>>>>> $e');
    }
  }

  /// Update the list of supported media files
  void refreshList() async {
    List<MediaFile> files = await _mediaFiles.buildList(
        directory: mediaDirectory,
        callback: (() {
          setState(() {
            // Update the UI
            statusText = "UPDATE UI";
          });
        }));
    for (final file in files) {
      print("media file: ${file.baseFileName}");
    }
  }

  void menuAction(String menuItem) {
    print("Menu: $menuItem");
    switch (menuItem) {
      case (Menu.SetDirectory):
        selectDirectory(((newDirName) {
          setState(() {
            mediaDirectory = newDirName;
            statusText = "New dir: $newDirName";
            print("Dir: $mediaDirectory");
          });
        }));
        break;
      case (Menu.ChangeTheme):
        changeTheme();
        break;
      case (Menu.Refresh):
        refreshList();
        break;
      case (Menu.Exit):
        exit(0);
    }
  }

  /// Toggle through the themes.
  /// This sets the new theme and basically invalidates the app, forcing it to restart.
  void changeTheme() {
    String theme;
    if (ApplicationSetting.systemTheme) {
      theme = "dark";
    } else if (ApplicationSetting.darkTheme) {
      theme = "light";
    } else {
      theme = "system";
    }
    setTheme(themeName: theme);
    // The theme is set all the way in the beginning of the app.  Restart the app:
    Phoenix.rebirth(this.context);
  }

  /// Set the application's theme
  void setTheme({required String themeName}) {
    switch (themeName) {
      case "system":
        ApplicationSetting.systemTheme = true;
        ApplicationSetting.darkTheme = false;
        break;
      case "dark":
        ApplicationSetting.systemTheme = false;
        ApplicationSetting.darkTheme = true;
        break;
      case "light":
        ApplicationSetting.systemTheme = false;
        ApplicationSetting.darkTheme = false;
        break;
    }
    statusText = "Switching to $themeName theme";
    settingsDatabase.update(type: "setting", key: "theme", value: themeName);
  }

  void onTabChange() {
    if (!tabController.indexIsChanging) {
      currentTab = tabController.index;
    }
  }

  Future<String> selectFolder(Function callback) async {
// Get root directory:
//    String rootDirectory = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.ROO);
    String? path = await FilesystemPicker.open(
      title: 'Select folder',
      context: this.context,
      rootDirectory: Directory("/storage/emulated/0/"),
      fsType: FilesystemType.folder,
      pickText: 'Select media folder',
    );
    callback(path);
    return path ?? "";
  }

  void selectDirectory(Function callback) {
    final dirController = TextEditingController(text: mediaDirectory);

    showDialog(
        context: this.context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Media Directory'),
            content: SingleChildScrollView(
                child: ListBody(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Text('Name:'),
                    SizedBox(
                      width: 190,
                      child: TextField(
                        controller: dirController,
                      ),
                    ),
                    IconButton(
                      onPressed: (() {
                        selectFolder((newFolder) {
                          setState(() {
                            statusText = "Folder: $newFolder";
                            print("Folder: $newFolder");
                            mediaDirectory = newFolder;
                            dirController.text = newFolder;
                            refreshList();
                          });
                        });
                      }),
                      icon: const Icon(Icons.folder),
                    )
                  ],
                ),
              ],
            )),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Save'),
                onPressed: () {
                  callback(dirController.text);
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    // We need our own custom tab controller to keep track of which tab is active:
    tabController = TabController(length: tabNames.length, vsync: this, initialIndex: currentTab);
    tabController.addListener(onTabChange);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        foregroundColor: Colors.yellow,
        backgroundColor: Colors.green[900],
        bottom: TabBar(
          controller: tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: const LinearGradient(
              colors: [Colors.yellow, Colors.amberAccent],
            ),
          ),
          unselectedLabelColor: Colors.grey,
          tabs: <Widget>[
            for (var tabName in tabNames)
              Tab(
                text: tabName,
              )
          ],
        ),
        actions: <Widget>[
          IconButton(icon: Icon(Icons.refresh), onPressed: () => refreshList()),
          PopupMenuButton<String>(
            onSelected: menuAction,
            itemBuilder: (BuildContext context) {
              return Menu.menuItems.map((String menuItem) {
                return PopupMenuItem<String>(
                  value: menuItem,
                  child: Row(
                    children: [
                      Text(menuItem),
                      Icon(Icons.edit),
                    ],
                  ),
                );
              }).toList();
            },
          )
        ],
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
                    setState(() {
                      statusText = "click $song";
                    });
                  },
                );
              },
            )
          : const Center(child: Text('No Files')),
      bottomNavigationBar: Container(
        color: Colors.green[900],
        child: Text(statusText, style: TextStyle(color: Colors.yellow)),
      ),
    );
  }
}
