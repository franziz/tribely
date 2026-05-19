import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tribely/src/core/storage/intro_flag_storage.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late MockSharedPreferences prefs;
  late IntroFlagStorage storage;

  setUp(() {
    prefs = MockSharedPreferences();
    storage = IntroFlagStorage(prefs);
  });

  const key = 'safety_check_in_intro';
  const storedKey = 'intro_flag_$key';

  group('hasSeen', () {
    test('returns false when key is absent (null from prefs)', () async {
      when(() => prefs.getBool(storedKey)).thenReturn(null);

      final result = await storage.hasSeen(key);

      expect(result, isFalse);
    });

    test('returns false when prefs stores false', () async {
      when(() => prefs.getBool(storedKey)).thenReturn(false);

      final result = await storage.hasSeen(key);

      expect(result, isFalse);
    });

    test('returns true after markSeen was called', () async {
      when(() => prefs.getBool(storedKey)).thenReturn(true);

      final result = await storage.hasSeen(key);

      expect(result, isTrue);
    });
  });

  group('markSeen', () {
    test('writes true under the namespaced key', () async {
      when(() => prefs.setBool(storedKey, true)).thenAnswer((_) async => true);

      await storage.markSeen(key);

      verify(() => prefs.setBool(storedKey, true)).called(1);
    });
  });

  group('namespacing', () {
    test('two different keys do not collide', () async {
      const keyA = 'intro_a';
      const keyB = 'intro_b';

      when(() => prefs.getBool('intro_flag_$keyA')).thenReturn(true);
      when(() => prefs.getBool('intro_flag_$keyB')).thenReturn(null);

      expect(await storage.hasSeen(keyA), isTrue);
      expect(await storage.hasSeen(keyB), isFalse);
    });
  });
}
