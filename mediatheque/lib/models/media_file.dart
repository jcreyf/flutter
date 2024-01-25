import 'dart:io' as io;
import 'package:path/path.dart';
import 'package:mediatheque/repositories/media_file_table.dart';

/// Closs to hold info about a single media file.
class MediaFile {
  String _fileName = "";
  String _fileLocation = "";
  int _fileSize = 0;
  Duration _duration = Duration.zero;
  int _lastListenedSecond = 0;
  bool _playedToTheEnd = false;
  String? createdAt;
  String? updatedAt;

  /// Constructor (taking all fields so that we can create an instance from a JSON serialized SQLite record).
  MediaFile(
      {required String fileName,
      String fileLocation = "",
      int fileSize = 0,
      Duration duration = Duration.zero,
      int lastListenedSecond = 0,
      bool playedToTheEnd = false,
      // When was the record created/updated:
      this.createdAt,
      this.updatedAt}) {
    _fileName = fileName;
    _fileLocation = fileLocation;
    _fileSize = fileSize;
    _duration = duration;
    _lastListenedSecond = lastListenedSecond;
    _playedToTheEnd = playedToTheEnd;
  }

  /// Create a MediaFile object instance from a JSON record.
  factory MediaFile.fromSqfliteDatabase(Map<String, dynamic> map) => MediaFile(
        fileName: map['file_name'] ?? '',
        fileLocation: map['file_location'] ?? '',
        fileSize: map['file_size'],
        duration: Duration(seconds: map['duration_seconds'] ?? Duration.zero),
        lastListenedSecond: map['last_listened_second'],
        playedToTheEnd: map['played_to_end'] == 1,
        createdAt: DateTime.fromMicrosecondsSinceEpoch(map['created_at']).toIso8601String(),
        updatedAt: map['updated_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(map['updated_at']).toIso8601String(),
      );

  /// Get the time duration in a human readable format: HH:MM:SS
  static String formatTime({required Duration time}) {
//    return "${time.inHours.toString().length <= 1 ? "0${time.inHours}" : "${time.inHours}"}:${time.inMinutes.remainder(60).toString().length <= 1 ? "0${time.inMinutes.remainder(60)}" : "${time.inMinutes.remainder(60)}"}:${time.inSeconds.remainder(60).toString().length <= 1 ? "0${time.inSeconds.remainder(60)}" : "${time.inSeconds.remainder(60)}"}";
    return time.toString().split('.')[0].padLeft(8, '0');
  }

  @override
  String toString() {
    return '$_fileLocation/$_fileName';
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
    return "${_fileLocation}/${_fileName}";
  }

  set fileFullPath(String fullPath) {
    if (!io.File(fullPath).existsSync()) {
      throw Exception("File does not exist! ($fullPath)");
    }
    _fileName = basename(fullPath);
    _fileLocation = io.File(fullPath).parent.path;
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

  /// Keep track of how long the audio is in this file.
  set duration(Duration value) {
    _duration = value;
//    print("$_fileName - $_duration");
  }

  /// Return the length of the audio in the file.
  Duration get duration {
//    return "${_duration.inHours.toString().length <= 1 ? "0${_duration.inHours}" : "${_duration.inHours}"}:${_duration.inMinutes.remainder(60).toString().length <= 1 ? "0${_duration.inMinutes.remainder(60)}" : "${_duration.inMinutes.remainder(60)}"}:${_duration.inSeconds.remainder(60).toString().length <= 1 ? "0${_duration.inSeconds.remainder(60)}" : "${_duration.inSeconds.remainder(60)}"}";
    return _duration;
  }

  String getDurationString() {
    return MediaFile.formatTime(time: _duration);
  }

  /// Mark the file as completely listened to.
  /// We use this flag mostly for podcasts to determine that we already listenend to this and the file can be removed.
  set playedToTheEnd(bool flag) {
    _playedToTheEnd = flag;
  }

  /// Determine if the we listened all the way to the end of this file.
  /// We use this flag mostly for podcasts to determine that we already listenend to this and the file can be removed.
  bool get playedToTheEnd {
    return _playedToTheEnd;
  }

  Future<void> saveToDB() async {
    await MediaFileTable().create(
      fileName: _fileName,
      fileLocation: _fileLocation,
      fileSize: _fileSize,
      durationSeconds: _duration.inSeconds,
    ).then((id) => print("inserted $id record for $fileName"));
  }

  /// Update the record in the backend database to keep track of where we are in the media file.
  /// This data is used later if we stopped the application for whatever reason and start it up again later to continue
  /// listening where we left off.
  Future<void> savePlaybackLocation({required int seconds}) async {
    _lastListenedSecond = seconds;
    await MediaFileTable().updateLastPlaybackLocation(
      fileName: _fileName,
      fileLocation: _fileLocation,
      fileSize: _fileSize,
      lastListenedSecond: _lastListenedSecond,
    );
  }
  
  /// Update the record in the backend database to keep track of which media file we finished listening to.
  /// This is mostly useful to keep track of podcasts in a playlist so that we can cirle back later and remove
  /// the ones we finished listening to.
  Future<void> savePlayedToEnd() async {
    await MediaFileTable().updateLastPlaybackLocation(
      fileName: _fileName,
      fileLocation: _fileLocation,
      fileSize: _fileSize,
      lastListenedSecond: _duration.inSeconds,
      playedToEnd: _playedToTheEnd,
    );
  }

  /// Get the playtime details for this media file from the backend database.
  Future<void> getPlaytimeData() async {
    MediaFile data = await MediaFileTable().fetchByFileName(fileName: _fileName, fileLocation: _fileLocation, fileSize: _fileSize);
    _lastListenedSecond = data.lastListenedSecond;
    _playedToTheEnd = data.playedToTheEnd;
  }
}
