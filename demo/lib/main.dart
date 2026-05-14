import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ur_android_frame/ur_android_frame.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  UrConfig.init(baseUrl: 'http://10.0.2.2:3003');
  runApp(const UrDemoApp());
}

class UrDemoApp extends StatefulWidget {
  const UrDemoApp({super.key});

  @override
  State<UrDemoApp> createState() => _UrDemoAppState();
}

class _UrDemoAppState extends State<UrDemoApp> {
  final _locale = ValueNotifier<Locale>(Locale.enUs);
  final _availableLocales = ValueNotifier<List<Locale>?>(null);
  final _localeBcp47 = ValueNotifier<String>('en-US');

  final _themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);

  final _session = ValueNotifier<SessionInfo?>(null);
  final _signinOpen = ValueNotifier<bool>(false);
  final _canSignIn = ValueNotifier<bool>(true);
  final _roleRefresh = ValueNotifier<int>(0);

  final _roles = ValueNotifier<List<RoleInfo>>([]);

  final _zoneCountryCode = ValueNotifier<String?>(null);
  final _zoneState = ValueNotifier<String?>(null);
  final _zoneCity = ValueNotifier<String?>(null);
  final _zoneCountryName = ValueNotifier<String?>(null);

  final _translationStore = TranslationStore();

  @override
  void initState() {
    super.initState();

    _locale.addListener(() {
      _localeBcp47.value = _locale.value.bcp47;
      _translationStore.fetch(_locale.value.bcp47);
    });

    _session.addListener(_fetchRoles);
    _roleRefresh.addListener(_fetchRoles);

    _fetchLocales();
    _fetchSession();
    _translationStore.fetch('en-US');
  }

  @override
  void dispose() {
    _locale.dispose();
    _availableLocales.dispose();
    _localeBcp47.dispose();
    _themeMode.dispose();
    _session.dispose();
    _signinOpen.dispose();
    _canSignIn.dispose();
    _roleRefresh.dispose();
    _roles.dispose();
    _zoneCountryCode.dispose();
    _zoneState.dispose();
    _zoneCity.dispose();
    _zoneCountryName.dispose();
    _translationStore.dispose();
    super.dispose();
  }

  Future<void> _fetchLocales() async {
    try {
      final resp = await http.get(Uri.parse('${UrConfig.baseUrl}/app/locales'));
      if (resp.statusCode != 200) return;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (body['locales'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((e) => Locale.fromBcp47(e['code'] as String))
          .whereType<Locale>()
          .toList();
      if (list.isNotEmpty) _availableLocales.value = list;
    } catch (_) {}
  }

  Future<void> _fetchSession() async {
    try {
      final resp = await http.get(Uri.parse('${UrConfig.baseUrl}/me/session'));
      if (resp.statusCode == 200) {
        _session.value = SessionInfo.fromJson(jsonDecode(resp.body));
      }
    } catch (_) {}
  }

  Future<void> _fetchRoles() async {
    if (_session.value == null) {
      _roles.value = [];
      return;
    }
    try {
      final resp = await http.get(Uri.parse('${UrConfig.baseUrl}/me/roles'));
      if (resp.statusCode == 200) {
        final body = RolesResponse.fromJson(jsonDecode(resp.body));
        _roles.value = body.roles;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'ur-android-frame Demo',
          debugShowCheckedModeBanner: false,
          theme: createUrThemeData(const UrColorScheme.light()),
          darkTheme: createUrThemeData(const UrColorScheme.dark()),
          themeMode: mode,
          home: _Home(state: this),
        );
      },
    );
  }
}

class _Home extends StatelessWidget {
  final _UrDemoAppState state;
  const _Home({required this.state});

  @override
  Widget build(BuildContext context) {
    final mode = state._themeMode.value;
    final scheme = mode == ThemeMode.light
        ? const UrColorScheme.light()
        : const UrColorScheme.dark();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _Toolbar(scheme: scheme, state: state),
            ListenableBuilder(
              listenable: state._translationStore,
              builder: (context, _) => SignInModal(
                open: state._signinOpen,
                session: state._session,
                translations: ValueNotifier(state._translationStore.map),
                locale: state._localeBcp47,
                availableLocales: state._availableLocales,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final UrColorScheme scheme;
  final _UrDemoAppState state;

  const _Toolbar({required this.scheme, required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: UrSpacing.md, vertical: UrSpacing.sm),
      child: Wrap(
        spacing: UrSpacing.md,
        runSpacing: UrSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ListenableBuilder(
            listenable: state._translationStore,
            builder: (context, _) => SignInLink(
              session: state._session,
              canSignIn: state._canSignIn,
              modalOpen: state._signinOpen,
              translations: ValueNotifier(state._translationStore.map),
            ),
          ),
          ListenableBuilder(
            listenable: state._translationStore,
            builder: (context, _) => SignOutLink(
              session: state._session,
              roleRefresh: state._roleRefresh,
              translations: ValueNotifier(state._translationStore.map),
            ),
          ),

          ZoneDetector(
            countryCode: state._zoneCountryCode,
            detectedState: state._zoneState,
            detectedCity: state._zoneCity,
            detectedCountry: state._zoneCountryName,
            translations: state._translationStore.map != null
                ? ValueNotifier(state._translationStore.map)
                : null,
          ),
          ZoneAiList(
            countryCode: state._zoneCountryCode,
            state: state._zoneState,
            city: state._zoneCity,
            country: state._zoneCountryName,
            translations: state._translationStore.map != null
                ? ValueNotifier(state._translationStore.map)
                : null,
            locale: state._localeBcp47,
          ),

          _Labeled(
            translationsKey: 'theme_toggle.label',
            translationStore: state._translationStore,
            child: ThemeToggle(
              themeMode: state._themeMode,
            ),
          ),

          _Labeled(
            translationsKey: 'locale.label',
            translationStore: state._translationStore,
            child: LangSelector(
              locale: state._locale,
              availableLocales: state._availableLocales,
            ),
          ),

          ValueListenableBuilder<Locale>(
            valueListenable: state._locale,
            builder: (_, loc, _) => Text(loc.label, style: TextStyle(
              fontSize: UrFontSizes.sm,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            )),
          ),

          _Labeled(
            translationsKey: 'roles.label',
            translationStore: state._translationStore,
            child: ValueListenableBuilder<List<RoleInfo>>(
              valueListenable: state._roles,
              builder: (_, roles, _) {
                if (roles.isEmpty) return const SizedBox.shrink();
                return RoleBadgeList(
                  roles: roles,
                  translations: state._translationStore.map != null
                      ? ValueNotifier(state._translationStore.map)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  final String translationsKey;
  final TranslationStore translationStore;
  final Widget child;

  const _Labeled({
    required this.translationsKey,
    required this.translationStore,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: translationStore,
      builder: (context, _) {
        final tm = translationStore.map;
        final raw = tm?.get(translationsKey) ?? translationsKey;
        final label = raw == translationsKey ? '' : raw;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: UrSpacing.xs),
                child: Text(label, style: TextStyle(
                  fontSize: UrFontSizes.sm,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                )),
              ),
            child,
          ],
        );
      },
    );
  }
}
