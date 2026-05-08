/// Shared configuration for ur-android-frame consumers.
///
/// Call `UrConfig.init(...)` once at startup with the backend base URL.
class UrConfig {
  UrConfig._();

  static String _baseUrl = 'http://10.0.2.2:3003';

  /// Base URL for all API calls. Defaults to the Android emulator alias
  /// for the host machine (`10.0.2.2`).
  static String get baseUrl => _baseUrl;

  static void init({required String baseUrl}) {
    _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  }
}
