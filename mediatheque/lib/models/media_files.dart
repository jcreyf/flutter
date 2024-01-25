import 'dart:io';
import 'dart:async';
import 'package:mediatheque/models/media_file.dart';
import 'package:mediatheque/repositories/database_service.dart';
import 'package:mediatheque/repositories/media_file_table.dart';
import 'package:path/path.dart';
// Used to get metadata from the media files:
import 'package:just_audio/just_audio.dart';
// Needed for the MediaItem class:
//   https://pub.dev/packages/audio_service
//   /> flutter pub add audio_service
import 'package:audio_service/audio_service.dart';

/// Class to keep a collection of MediaFile instances.
class MediaFiles {
  List<MediaFile> _mediaFiles = [];
  static final List<String> supportedExtensions = [".mp3", ".wmv"];

  List<MediaFile> get files {
    return _mediaFiles;
  }

  Future<List<MediaFile>> buildList({required String directory, required Function callback}) async {
    Directory dir = Directory.fromUri(Uri(path: directory));
    var completer = Completer<List<MediaFile>>();
    _mediaFiles.clear();
    AudioPlayer player = AudioPlayer();

    print("List files in: ${dir.path}");

    var lister = dir.list(recursive: true);
    lister.listen((file) async {
      if (file is File) {
        // Only use supported files:
        final String fileName = basename(file.path);
        final String directory = file.parent.path;
        if (supportedExtensions.contains(extension(fileName))) {
          print("Working with: $fileName");
//          final playList = ConcatenatingAudioSource(children: [
//            AudioSource.uri(Uri.parse(file.path),
//                tag: MediaItem(
//                    id: "0",
//                    title: file.path,
//                    artist: "Mediatheque",
//                    album: "album",
//                  displayDescription: "description",
//                    duration: Duration.zero))
//          ]);
//          try {
//            await player.setAudioSource(playList, preload: true).then((duration) {
//              print("file: ${file.path}, duration: $duration");
          MediaFile mediaFile = MediaFile(fileName: fileName, fileLocation: directory, fileSize: file.lengthSync());
          _mediaFiles.add(mediaFile);
//            });
//          } on PlayerInterruptedException catch (e) {
//            print("Exception: $e");
//          }

//          if (audioDuration != null) {
//            audioEndTime.value = "${audioDuration.inMinutes.remainder(60).toString().padLeft(2, "0")}:${audioDuration.inSeconds.remainder(60).toString().padLeft(2, "0")}";
//          }
        } else {
          print("File not supported: $fileName");
        }
      }
    },
        // should also register onError
        onDone: () async {
      // Loop through the media files and figure out how long each file is.
// ToDo: this needs to be done async in the background
// ToDo: this is throwing an error if done while the app is playing audio.  Need to look into using a separate audio handler for this in the background
      for (MediaFile mediaFile in _mediaFiles) {
        print("Do: $mediaFile");
        final playList = ConcatenatingAudioSource(
            children: [
              AudioSource.uri(
                  Uri.parse(mediaFile.fileFullPath),
                  tag: MediaItem(
                    id: "0",
                    title: mediaFile.baseFileName,
                    artist: "Mediatheque",
                    album: "album",
                    displayDescription: "description",
                    duration: Duration.zero,
                  )),
            ]);
        await player.setAudioSource(playList, preload: true).then((duration) async {
          mediaFile.duration = duration ?? Duration.zero;
          print("file: ${mediaFile.fileName}, duration: $duration");
//          try {
          // We had to start a player to get to the media length.  Stop the player:
          await player.stop();
          // Save the media file details in the backend database so we can keep track of it:
          await mediaFile.saveToDB();
//          } on Exception catch (e) {}
        });
      }
      callback();
    });

    return completer.future;
  }

  /// Clear the app's cache by deleting all reconds in the backend database.
  Future<void> clearCache() async {
    await MediaFileTable().deleteAll();
    _mediaFiles.clear();
  }
}
