import 'dart:io' as io;
import 'package:path/path.dart';

class MediaFile {
  String _fileName = "";
  String _fileLocation = "";
  int _lengthInSeconds = 0;
  int _lastListenedSecond = 0;

  MediaFile({required String filename}) {
    _fileName = filename;
  }

  @override
  String toString() {
    return '$_fileName ($_lengthInSeconds seconds)';
  }

  String get fileName {
    return _fileName;
  }

  String get baseFileName {
    return basenameWithoutExtension(_fileName);
  }

  set fileName(String name) {
    _fileName = name;
  }

  String get fileLocation {
    return _fileLocation;
  }

  set fileLocation(String location) {
    _fileLocation = location;
  }

  String get fileFullPath {
    return "${_fileLocation}\${_fileName}";
  }

  set fileFullPath(String fullPath) {
    if (!io.File(fullPath).existsSync()) {
      throw Exception("File does not exist! ($fullPath)");
    }
    _fileName = basename(fullPath);
  }

  String get fileExtension {
    return extension(_fileName);
  }

  int get lastListenedSecond {
    return _lastListenedSecond;
  }

  set lastListenedSecond(int second) {
    _lastListenedSecond = second;
  }

  void resetListeningTime() {
    _lastListenedSecond = 0;
  }

  int get mediaNumberOfSeconds {
    return _lengthInSeconds;
  }
}
