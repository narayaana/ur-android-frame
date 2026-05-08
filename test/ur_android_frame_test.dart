import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_android_frame/ur_android_frame.dart';

void main() {
  group('Locale', () {
    test('all returns all 8 variants', () {
      expect(Locale.all.length, 8);
    });

    test('fromBcp47 exact match', () {
      expect(Locale.fromBcp47('en-US'), Locale.enUs);
      expect(Locale.fromBcp47('fr-FR'), Locale.frFr);
      expect(Locale.fromBcp47('nl-NL'), Locale.nlNl);
      expect(Locale.fromBcp47('de-DE'), Locale.deDe);
      expect(Locale.fromBcp47('es-ES'), Locale.esEs);
      expect(Locale.fromBcp47('zh-Hant-HK'), Locale.zhHantHk);
      expect(Locale.fromBcp47('yue-HK'), Locale.yueHk);
      expect(Locale.fromBcp47('sw-KE'), Locale.swKe);
    });

    test('fromBcp47 case insensitive', () {
      expect(Locale.fromBcp47('en-us'), Locale.enUs);
      expect(Locale.fromBcp47('EN-US'), Locale.enUs);
    });

    test('fromBcp47 primary subtag fallback', () {
      expect(Locale.fromBcp47('fr-CA'), Locale.frFr);
      expect(Locale.fromBcp47('zh-Hans-CN'), Locale.zhHantHk);
    });

    test('fromBcp47 unknown returns null', () {
      expect(Locale.fromBcp47('ja-JP'), null);
    });

    test('bcp47 returns valid tag', () {
      for (final l in Locale.all) {
        expect(l.bcp47, isNotEmpty);
        expect(l.bcp47, contains('-'));
      }
    });

    test('flag returns non-empty emoji', () {
      for (final l in Locale.all) {
        expect(l.flag, isNotEmpty);
        expect(l.flag.length, greaterThan(1));
      }
    });

    test('label returns non-empty string', () {
      for (final l in Locale.all) {
        expect(l.label, isNotEmpty);
      }
    });
  });

  group('TranslationMap', () {
    test('get returns value for known key', () {
      final tm = TranslationMap({'sign_in.link': 'Sign-in'});
      expect(tm.get('sign_in.link'), 'Sign-in');
    });

    test('get falls back to key for unknown key', () {
      final tm = TranslationMap({});
      expect(tm.get('unknown.key'), 'unknown.key');
    });

    test('fromEntries builds correct map', () {
      final entries = [
        TranslationEntry(objectTag: 'a', value: '1'),
        TranslationEntry(objectTag: 'b', value: '2'),
      ];
      final tm = TranslationMap.fromEntries(entries);
      expect(tm.get('a'), '1');
      expect(tm.get('b'), '2');
    });

    test('isEmpty returns true for empty map', () {
      expect(TranslationMap({}).isEmpty, isTrue);
      expect(TranslationMap({'a': 'b'}).isEmpty, isFalse);
    });
  });

  group('Data classes', () {
    test('SessionInfo.fromJson parses correctly', () {
      final s = SessionInfo.fromJson({'username': 'test', 'id': '123'});
      expect(s.username, 'test');
      expect(s.id, '123');
    });

    test('RoleInfo.fromJson parses correctly', () {
      final r = RoleInfo.fromJson({'code': 'admin', 'label': 'Admin'});
      expect(r.code, 'admin');
      expect(r.label, 'Admin');
    });

    test('ZoneData.fromJson parses ai_models', () {
      final json = {
        'id': 'z1',
        'code': 'zone-us',
        'name': 'United States',
        'localized_names': [],
        'ai_models': [
          {'id': 'ai1', 'code': 'gpt4', 'name': 'GPT-4', 'localized_names': []},
        ],
      };
      final z = ZoneData.fromJson(json);
      expect(z.id, 'z1');
      expect(z.aiModels.length, 1);
      expect(z.aiModels.first.code, 'gpt4');
      expect(z.country, null);
    });
  });

  group('Theme serialization', () {
    test('themeModeFromString parses correctly', () {
      expect(themeModeFromString('dark'), ThemeMode.dark);
      expect(themeModeFromString('light'), ThemeMode.light);
      expect(themeModeFromString('system'), ThemeMode.system);
      expect(themeModeFromString(null), ThemeMode.system);
      expect(themeModeFromString('unknown'), ThemeMode.system);
    });

    test('themeModeToString round-trips', () {
      for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
        expect(themeModeFromString(themeModeToString(mode)), mode);
      }
    });
  });

  group('Design tokens', () {
    test('dark scheme has correct bg color', () {
      const s = UrColorScheme.dark();
      expect(s.bg, const Color(0xFF0A0A12));
    });

    test('light scheme has correct bg color', () {
      const s = UrColorScheme.light();
      expect(s.bg, const Color(0xFFEEF0F7));
    });

    test('createUrThemeData produces ThemeData', () {
      final td = createUrThemeData(const UrColorScheme.dark());
      expect(td.scaffoldBackgroundColor, const Color(0xFF0A0A12));
    });
  });

  group('Widget tests', () {
    testWidgets('ThemeToggle renders', (tester) async {
      final mode = ValueNotifier<ThemeMode>(ThemeMode.dark);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ThemeToggle(themeMode: mode))));
      await tester.pumpAndSettle();
      expect(find.byType(ThemeToggle), findsOneWidget);
    });

    testWidgets('RoleBadgeList renders badges', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RoleBadgeList(roles: [
            RoleInfo(code: 'anonymous', label: 'Anonymous'),
            RoleInfo(code: 'member', label: 'Member'),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Anonymous'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
    });

    testWidgets('SignInLink shows sign-in button when no session', (tester) async {
      final session = ValueNotifier<SessionInfo?>(null);
      final canSignIn = ValueNotifier<bool>(true);
      final modalOpen = ValueNotifier<bool>(false);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SignInLink(
            session: session,
            canSignIn: canSignIn,
            modalOpen: modalOpen,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Sign-in'), findsOneWidget);
    });

    testWidgets('SignInLink hides when blocked', (tester) async {
      final session = ValueNotifier<SessionInfo?>(null);
      final canSignIn = ValueNotifier<bool>(false);
      final modalOpen = ValueNotifier<bool>(false);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SignInLink(
            session: session,
            canSignIn: canSignIn,
            modalOpen: modalOpen,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Sign-in'), findsNothing);
    });
  });
}
