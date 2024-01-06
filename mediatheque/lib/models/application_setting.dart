/// Class to describe a single application setting
class ApplicationSetting {
  final String type;
  final String key;
  final String value;
  final String createdAt;
  final String? updatedAt;

  static bool systemTheme = true;
  static bool darkTheme = false;
  static String defaultTab = "";

  /// Constructor
  ApplicationSetting({
    required this.type,
    required this.key,
    required this.value,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create an application setting object instance from a JSON record
  factory ApplicationSetting.fromSqfliteDatabase(Map<String, dynamic> map) => ApplicationSetting(
        type: map['type'] ?? '',
        key: map['key'] ?? '',
        value: map['value'] ?? '',
        createdAt: DateTime.fromMicrosecondsSinceEpoch(map['created_at']).toIso8601String(),
        updatedAt: map['updated_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(map['updated_at']).toIso8601String(),
      );

  String toString() {
    return "Type: $type, key: $key, value: $value";
  }
}
