import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

/// A single translation entry from the backend.
class TranslationEntry {
  final String objectTag;
  final String value;
  const TranslationEntry({required this.objectTag, required this.value});

  factory TranslationEntry.fromJson(Map<String, dynamic> json) =>
      TranslationEntry(objectTag: json['object_tag'] as String, value: json['value'] as String);
}

/// The backend's full translation response.
class TranslationsResponse {
  final List<TranslationEntry> translations;
  const TranslationsResponse({required this.translations});

  factory TranslationsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['translations'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(TranslationEntry.fromJson)
        .toList();
    return TranslationsResponse(translations: list);
  }
}

/// Reactive translation lookup table.
///
/// `get(key)` returns the translation value, or falls back to the key itself
/// when no translation exists — mirroring ur-web-frame's [TranslationMap].
class TranslationMap {
  final Map<String, String> _map;
  TranslationMap(Map<String, String> map) : _map = _canonical(map);

  factory TranslationMap.fromEntries(List<TranslationEntry> entries) {
    final map = <String, String>{};
    for (final e in entries) {
      map[e.objectTag] = e.value;
    }
    return TranslationMap(map);
  }

  /// Returns the translation for [key], or [key] itself as a fallback.
  /// Canonicalises to dot separators so `sign_in.link` and `sign_in.link` both work.
  String get(String key) => _map[key] ?? key;

  bool get isEmpty => _map.isEmpty;

  static Map<String, String> _canonical(Map<String, String> map) {
    final out = <String, String>{};
    for (final e in map.entries) {
      out[e.key] = e.value;
      // Also store a dot-normalised alias so underscore-based lookups match.
      final dot = e.key.replaceAll('_', '.');
      if (dot != e.key) out[dot] = e.value;
    }
    return out;
  }
}

/// Reactive translation store — re-fetches when the locale changes.
///
/// Call `fetch(localeBcp47)` to load translations. Components read the
/// current map via [map].
class TranslationStore extends ChangeNotifier {
  TranslationMap? _map;
  TranslationMap? get map => _map;

  String _locale = '';

  Future<void> fetch(String localeBcp47) async {
    if (localeBcp47 == _locale) return;
    _locale = localeBcp47;
    try {
      final resp = await http.get(Uri.parse('${UrConfig.baseUrl}/app/translations/$localeBcp47'));
      if (resp.statusCode == 200) {
        final body = TranslationsResponse.fromJson(jsonDecode(resp.body));
        _map = TranslationMap.fromEntries(body.translations);
      } else {
        _map = TranslationMap({});
      }
    } catch (_) {
      _map = TranslationMap({});
    }
    notifyListeners();
  }
}
