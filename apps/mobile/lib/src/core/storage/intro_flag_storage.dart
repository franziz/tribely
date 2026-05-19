import 'package:shared_preferences/shared_preferences.dart';

/// Flat-file persistence for one-time intro/onboarding sheet flags.
///
/// Backed by [SharedPreferences] (non-sensitive boolean flags — no encryption
/// required; compare with [TokenStorage] which uses flutter_secure_storage for
/// auth secrets).
///
/// Keys are namespaced as `'intro_flag_<key>'` so multiple flags coexist
/// safely without collision. Callers use stable, feature-scoped string keys
/// (e.g. `'safety_check_in_intro'`).
///
/// Usage:
/// ```dart
/// if (!await introFlagStorage.hasSeen('safety_check_in_intro')) {
///   await introFlagStorage.markSeen('safety_check_in_intro');
///   // show intro sheet
/// }
/// ```
class IntroFlagStorage {
  IntroFlagStorage(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String key) => 'intro_flag_$key';

  /// Returns `true` if [markSeen] has previously been called for [key].
  Future<bool> hasSeen(String key) async => _prefs.getBool(_key(key)) ?? false;

  /// Records that the intro identified by [key] has been seen.
  /// Subsequent calls to [hasSeen] with the same [key] will return `true`.
  Future<void> markSeen(String key) async {
    await _prefs.setBool(_key(key), true);
  }
}
