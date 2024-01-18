import 'dart:io' as io;
import 'package:path/path.dart';

class MediaFile {
  String _fileName = "";
  String _fileLocation = "";
  Duration _duration = Duration.zero;
  int _lengthInSeconds = 0;
  int _lastListenedSecond = 0;

  MediaFile({required String filename}) {
    _fileName = filename;
  }

  /// Get the time duration in a human readable format: HH:MM:SS
  static String formatTime({required Duration time}) {
//    return "${time.inHours.toString().length <= 1 ? "0${time.inHours}" : "${time.inHours}"}:${time.inMinutes.remainder(60).toString().length <= 1 ? "0${time.inMinutes.remainder(60)}" : "${time.inMinutes.remainder(60)}"}:${time.inSeconds.remainder(60).toString().length <= 1 ? "0${time.inSeconds.remainder(60)}" : "${time.inSeconds.remainder(60)}"}";
    return time.toString().split('.')[0].padLeft(8, '0');
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

  set duration(Duration value) {
    _duration = value;
    print("$_fileName - $_duration");
  }

  Duration get duration {
//    return "${_duration.inHours.toString().length <= 1 ? "0${_duration.inHours}" : "${_duration.inHours}"}:${_duration.inMinutes.remainder(60).toString().length <= 1 ? "0${_duration.inMinutes.remainder(60)}" : "${_duration.inMinutes.remainder(60)}"}:${_duration.inSeconds.remainder(60).toString().length <= 1 ? "0${_duration.inSeconds.remainder(60)}" : "${_duration.inSeconds.remainder(60)}"}";
    return _duration;
  }
}
