import 'dart:io';
import 'dart:async';
//import 'package:path/path.dart';
import 'package:mediatheque/models/media_file.dart';
import 'package:path/path.dart';
// Used to get metadata from the media files:
import 'package:just_audio/just_audio.dart';
// Needed for the MediaItem class:
//   https://pub.dev/packages/audio_service
//   /> flutter pub add audio_service
import 'package:audio_service/audio_service.dart';

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
        if (supportedExtensions.contains(extension(file.path))) {
          print("Working with: ${file.path}");
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
          MediaFile mediaFile = MediaFile(filename: file.path);
          _mediaFiles.add(mediaFile);
//            });
//          } on PlayerInterruptedException catch (e) {
//            print("Exception: $e");
//          }

//          if (audioDuration != null) {
//            audioEndTime.value = "${audioDuration.inMinutes.remainder(60).toString().padLeft(2, "0")}:${audioDuration.inSeconds.remainder(60).toString().padLeft(2, "0")}";
//          }
        } else {
          print("File not supported: ${file.path}");
        }
      }
    },
        // should also register onError
        onDone: () async {
      for (MediaFile mediaFile in _mediaFiles) {
        print("Do: $mediaFile");
        final playList = ConcatenatingAudioSource(children: [AudioSource.uri(Uri.parse(mediaFile.fileName), tag: MediaItem(id: "0", title: mediaFile.baseFileName, artist: "Mediatheque", album: "album", displayDescription: "description", duration: Duration.zero))]);
        await player.setAudioSource(playList, preload: true).then((duration) async {
          mediaFile.duration = duration ?? Duration.zero;
          print("file: ${mediaFile.fileName}, duration: $duration");
//          try {
          await player.stop();
//          } on Exception catch (e) {}
        });
      }
      callback();
    });

    return completer.future;
  }
}
