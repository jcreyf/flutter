import 'dart:io';
import 'dart:async';
//import 'package:path/path.dart';
import 'package:mediatheque/models/media_file.dart';
import 'package:path/path.dart';
// Used to get metadata from the media files:
// import 'package:just_audio/just_audio.dart';

class MediaFiles {
  List<MediaFile> _mediaFiles = [];
  static final List<String> supportedExtensions = [".mp3", ".wmv"];

  List<MediaFile> get files {
    return _mediaFiles;
  }

  Future<List<MediaFile>> buildList({required String directory, required Function callback}) async {
    Directory dir = Directory.fromUri(Uri(path: directory));
    var completer = Completer<List<MediaFile>>();
//    AudioPlayer player = AudioPlayer();
    _mediaFiles.clear();

    print("List files in: ${dir.path}");

    var lister = dir.list(recursive: true);
    lister.listen((file) async {
      if (file is File) {
        // Only use supported files:
        if (supportedExtensions.contains(extension(file.path))) {
          MediaFile mediaFile = MediaFile(filename: file.path);
//          mediaFile.duration = await player.setFilePath(file.path) ?? Duration.zero;
          _mediaFiles.add(mediaFile);
        } else {
          print("File not supported: ${file.path}");
        }
      }
    },
        // should also register onError
        onDone: () {
// This is adding the list of files a second time! (all files ... without filtering)
//      completer.complete(_mediaFiles);
      callback();
    });

    return completer.future;
  }
}
