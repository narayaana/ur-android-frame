/// User preferences model — tagged flat format.
///
/// Mirrors the backend's `user_preferences` collection where each preference
/// is stored as `{ value: ..., category: "..." }` under a top-level key.
class PreferenceValue {
  final dynamic value;
  final String category;

  const PreferenceValue({required this.value, required this.category});

  factory PreferenceValue.fromJson(Map<String, dynamic> json) =>
      PreferenceValue(value: json['value'], category: json['category'] as String);

  Map<String, dynamic> toJson() => {'value': value, 'category': category};
}

/// The user's full preferences map — keyed by preference name.
class UserPreferences {
  final Map<String, PreferenceValue> entries;

  const UserPreferences({this.entries = const {}});

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final map = <String, PreferenceValue>{};
    json.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        map[key] = PreferenceValue.fromJson(val);
      }
    });
    return UserPreferences(entries: map);
  }

  Map<String, dynamic> toJson() =>
      entries.map((key, val) => MapEntry(key, val.toJson()));

  /// Get a string preference with a default fallback.
  String getString(String key, String defaultValue) =>
      (entries[key]?.value as String?) ?? defaultValue;

  /// Get a boolean preference with a default fallback.
  bool getBool(String key, bool defaultValue) =>
      (entries[key]?.value as bool?) ?? defaultValue;

  /// Convenience accessors.
  String get locale => getString('locale', 'en-US');
  String get theme => getString('theme', 'dark');
  bool get saveConversations => getBool('save_conversations', false);
}
