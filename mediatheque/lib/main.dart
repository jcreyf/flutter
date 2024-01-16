/*
  flutter build apk --release

  adb devices
  adb connect emulator-5554
  adb push ~/data/tmp/muziek 

*/

import 'package:mediatheque/models/application_setting.dart';
import 'package:mediatheque/repositories/mediatheque_setting.dart';
import 'package:mediatheque/models/media_files.dart';
import 'package:mediatheque/models/media_file.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:external_path/external_path.dart';
import 'package:path/path.dart';
// Logging stuff:
//   https://pub.dev/packages/logger
//   /> flutter pub add logger
import 'package:logger/logger.dart';
//   https://pub.dev/packages/permission_handler
//   https://github.com/baseflow/flutter-permission-handler
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
// Used to play audio:
//   https://pub.dev/packages/just_audio/install
//   /> flutter pub add just_audio
import 'package:just_audio/just_audio.dart';
// Used for playing media in the background:
import 'package:just_audio_background/just_audio_background.dart';
//import 'package:audio_session/audio_session.dart';

// Start point of the app.
// This needs to be a future / async method to support it running in the background
// (media playing in the background)
Future<void> main() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.jocreyf.mediatheque.channel.audio',
    androidNotificationChannelName: 'Mediatheque audio playback',
    androidNotificationOngoing: true,
  );
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
  final Logger logger = Logger();
  final settingsDatabase = SettingsDatabase();
  MediaFiles _mediaFiles = MediaFiles();
  late TabController tabController;
  List<String> tabNames = ["Media", "Player", "Logs"];
  int currentTab = 0;
  String statusText = "No Files...";
  String mediaDirectory = "";

  bool playing = false;
  MediaFile playingMediaFile = MediaFile(filename: "");
  late AudioPlayer player;
  Duration position = const Duration(seconds: 0);
  Duration musicLength = const Duration(seconds: 0);

  Widget slider() {
    return Column(
      children: <Widget>[
        const SizedBox(height: 50),
        playingMediaFile.fileName == ""
            ? const Text(
                "Nothing playing",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
              )
            : Text(
                playingMediaFile.baseFileName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 30),
              ),
        const SizedBox(height: 100),
        // The next widgets needs constant updating based on events in the autio sream:
        StreamBuilder(
            stream: player.positionStream,
            builder: (context, snapshot) {
              final Duration positionData = snapshot.data ?? const Duration();
              // Save the current timestamp every 30 seconds:
              if (positionData.inSeconds % 30 == 0) {
                playingMediaFile.lastListenedSecond = positionData.inSeconds;
              }
              return Column(
                children: [
                  // Media timestamps:
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        MediaFile.timeFormat(time: positionData ?? const Duration()),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 25),
                      ),
                      Text(
                        MediaFile.timeFormat(time: musicLength),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 25),
                      ),
                    ],
                  ),
                  // Media slider:
                  SliderTheme(
                    data: SliderTheme.of(widget.context).copyWith(
                      activeTrackColor: Colors.blue[950],
                      inactiveTrackColor: Colors.grey[500],
                      trackShape: const RectangularSliderTrackShape(),
                      trackHeight: 20.0,
                      thumbColor: Colors.blue[900],
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 20.0),
                      overlayColor: Colors.red.withAlpha(32),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 40.0),
                    ),
                    child: Container(
                      width: 400,
                      child: Slider(
                        min: 0.0,
                        max: musicLength.inSeconds.toDouble(),
                        divisions: 1 + musicLength.inSeconds,
                        value: positionData?.inSeconds.toDouble() ?? 0.0,
                        onChanged: (double moveToSec) {
                          setState(() {
                            print("slide value 2: $moveToSec");
                            seekToSec(moveToSec.toInt());
                          });
                        },
                      ),
                    ),
                  ),
                  // Media controls:
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.first_page, size: 50),
                        onPressed: () {
                          setState(() {
                            if (playing) {
                              player.seek(Duration.zero);
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.replay_30, size: 50),
                        onPressed: () {
                          setState(() {
                            if (playing) {
                              int currentSeconds = positionData.inSeconds;
                              if (currentSeconds > 30) {
                                player.seek(Duration(seconds: currentSeconds - 30));
                              } else {
                                player.seek(Duration.zero);
                              }
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: playingMediaFile.fileName != "" && playing ? const Icon(Icons.pause, size: 70) : const Icon(Icons.play_arrow, size: 70),
                        onPressed: () {
                          setState(() {
                            if (playing) {
                              player.stop();
                            } else {
                              player.play();
                            }
                            playing = !playing;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_30, size: 50),
                        onPressed: () {
                          setState(() {
                            if (playing) {
                              int currentSeconds = positionData.inSeconds;
                              int targetSeconds = currentSeconds + 30;
                              int totalSeconds = musicLength.inSeconds;
                              if (targetSeconds < totalSeconds) {
                                player.seek(Duration(seconds: targetSeconds));
                              }
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.last_page, size: 50),
                        onPressed: () {
                          setState(() {
                            if (playing) {
                              player.seek(musicLength);
                            }
                          });
                        },
                      ),
                    ],
                  )
                ],
              );
            }),
      ],
    );
  }

  void seekToSec(int sec) {
    Duration newPos = Duration(seconds: sec);
    player.seek(newPos);
  }

  @override
  void initState() {
    super.initState();

    checkPermission();
    loadSettings();

    player = AudioPlayer();
    // cache = AudioCache(fixedPlayer: player);
  }

  @override
  void dispose() {
    tabController.dispose();
    player.dispose();
    super.dispose();
  }

  /// Load the settings from the backend database.
  void loadSettings() {
    // Read all setting records asynchronously, then loop through them:
    print("Read settings...");
    settingsDatabase.fetchAll().then((settings) {
      print("Settings read!");
      print(settings);
      for (var setting in settings) {
        print("setting: ${setting.type} - ${setting.key} - ${setting.value}");
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
//        getPublicDirectoryPath();
        // Get a list of root paths and take the first:
        getRootPaths().then((dirList) {
          mediaDirectory = "${dirList[0]}/Download";
          // Get a file listing and update the UI:
          refreshList();
        });
      } else {
        // Get a file listing and update the UI:
        refreshList();
      }
    });
  }

  /// Get storage directory paths
  /// Like internal and external (SD card) storage path
  Future<List<String>> getRootPaths() async {
    List<String> paths;
    // getExternalStorageDirectories() will return list containing internal storage directory path
    // And external storage (SD card) directory path (if exists)
    paths = await ExternalPath.getExternalStorageDirectories();
    // ex: [/storage/emulated/0, /storage/B3AE-4D28]
    print("paths: $paths");
    return paths;
  }

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
            statusText = "Directory: $mediaDirectory";
          });
        }));
    for (final file in files) {
      print("media file: ${file.baseFileName}");
    }
  }

  /// Process a menu selection.
  void menuAction(String menuItem) {
    print("Menu: $menuItem");
    switch (menuItem) {
      case (Menu.SetDirectory):
        showDirectorySelector(((newDirName) {
          // A new directory was selected.  Save in the settings and get a new file list:
          setState(() {
            mediaDirectory = newDirName;
            statusText = "New dir: $newDirName";
            settingsDatabase.insertOrUpdate(type: "setting", key: "media_directory", value: newDirName);
            refreshList();
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
    settingsDatabase.insertOrUpdate(type: "setting", key: "theme", value: themeName);
  }

  void onTabChange() {
    if (!tabController.indexIsChanging) {
      currentTab = tabController.index;
    }
  }

  /// Show a directory selector popup
  Future selectDirectory(Function callback) async {
    // Get a list of root paths and take the 1st:
    late String rootDir;
    getRootPaths().then((dirList) async {
      rootDir = "${dirList[0]}/";
      statusText = "Root: $rootDir";
      String? path = await FilesystemPicker.open(
        title: 'Select folder',
        context: this.context,
        rootDirectory: Directory(rootDir),
        fsType: FilesystemType.folder,
        pickText: 'Select media folder',
      );
      callback(path);
    });
  }

  /// Show a window where the user can enter a directory
  void showDirectorySelector(Function callback) {
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
                    SizedBox(
                      width: 230,
                      child: TextField(
                        controller: dirController,
                      ),
                    ),
                    IconButton(
                      onPressed: () => selectDirectory((newFolder) {
                        // A new directory was selected.
                        // Save it in the settings and no need to continue the input.
                        statusText = "Folder: $newFolder";
                        callback(newFolder);
                        Navigator.of(context).pop();
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

  // await player.play();                            // Play while waiting for completion
  // await player.pause();                           // Pause but remain ready to play
  // await player.seek(Duration(second: 10));        // Jump to the 10 second position
  // await player.setSpeed(2.0);                     // Twice as fast
  // await player.setVolume(0.5);                    // Half as loud
  // await player.stop();                            // Stop and free resources
  void clickedFile(MediaFile mediaFile) async {
    if (mediaFile.fileName == playingMediaFile.fileName) {
      // The user clicked on the file that is currently playing.
      // Stop the player!
      await player.stop();
      playing = false;
      playingMediaFile = MediaFile(filename: "");
      setState(() {
        statusText = "stop playing: ${mediaFile.fileName}";
      });
    } else {
      // The user clicked on a file.
      // Start playing it!
      playingMediaFile = mediaFile;
      setState(() {
        statusText = "playing: ${playingMediaFile.fileName} (${MediaFile.timeFormat(time: musicLength)})";
      });
      await player.setFilePath(playingMediaFile.fileName).then((duration) {
        playing = true;
        musicLength = duration ?? const Duration(seconds: 0);
//        player.sequenceStateStream.listen((SequenceState? sequenceState) {
//          print("JCREYF sequence state: ${sequenceState?.currentSource.toString()}");
//        });
        // Jump to wherever we stopped listening last time:
        if (playingMediaFile.lastListenedSecond > 0) {
          player.seek(Duration(seconds: playingMediaFile.lastListenedSecond));
        }
        player.play();
      });
    }
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
                      const Icon(Icons.edit),
                    ],
                  ),
                );
              }).toList();
            },
          )
        ],
      ),
      body: TabBarView(
        controller: tabController,
        children: <Widget>[
          Container(
            // Body background
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green[900] ?? Colors.green,
                  Colors.green[200] ?? Colors.red,
                ],
              ),
            ),
            child: RefreshIndicator(
                onRefresh: () async {
                  // The page got pulled down.  We need to refresh the file list:
                  refreshList();
                },
                child: _mediaFiles.files.isNotEmpty
                    ? ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
                                      style: const TextStyle(fontSize: 18),
                                    ))),
                            onTap: () => clickedFile(song),
                          );
                        },
                      )
                    : const Center(child: Text('No Files'))),
          ),
          slider(),
          const Text("No logs"),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.green[900],
        child: Text(statusText, style: const TextStyle(color: Colors.yellow)),
      ),
    );
  }
}
