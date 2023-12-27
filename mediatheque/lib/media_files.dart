import 'dart:io' as io;
import 'package:path/path.dart';
import 'package:mediatheque/media_file.dart';

class MediaFiles {
  List<MediaFile> _mediaFiles = [];
  static final List<String> supportedExtensions = ["mp3", "wmv"];

  List<MediaFile> get files {
    return _mediaFiles;
  }

//  void buildList({required String directory}) async {
  Future<List> buildList({required String directory}) async {
    io.Directory dir = io.Directory.fromUri(Uri(path: directory));
    print("List files in: ${dir.path}");
//    List<String> bestanden=<String>[];
//    await for (final entity in dir.list()) {
//      print("file: ${entity.path}");
//      bestanden.add(entity.path);
//    }
    Future<List<String>> bestanden =
        dir.list().map((event) => event.path).toList();
    return bestanden;
  }
}
