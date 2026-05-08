import 'package:flutter/material.dart';
import 'tokens.dart';

/// BCP 47 locale enum — 7 supported languages + SwKe for testing.
///
/// Mirrors `ur_web_frame::Locale`.
enum Locale {
  enUs,
  frFr,
  nlNl,
  deDe,
  esEs,
  zhHantHk,
  yueHk,
  swKe;

  static List<Locale> get all => Locale.values;

  /// Unicode flag emoji for this locale.
  String get flag {
    switch (this) {
      case enUs:
        return '\u{1F1FA}\u{1F1F8}';
      case frFr:
        return '\u{1F1EB}\u{1F1F7}';
      case nlNl:
        return '\u{1F1F3}\u{1F1F1}';
      case deDe:
        return '\u{1F1E9}\u{1F1EA}';
      case esEs:
        return '\u{1F1EA}\u{1F1F8}';
      case zhHantHk:
        return '\u{1F1ED}\u{1F1F0}';
      case yueHk:
        return '\u{1F1ED}\u{1F1F0}';
      case swKe:
        return '\u{1F1F0}\u{1F1EA}';
    }
  }

  /// Native-language label.
  String get label {
    switch (this) {
      case enUs:
        return 'English (US)';
      case frFr:
        return 'Français';
      case nlNl:
        return 'Nederlands';
      case deDe:
        return 'Deutsch';
      case esEs:
        return 'Español';
      case zhHantHk:
        return '\u{7E41}\u{9AD4}\u{4E2D}\u{6587} (HK)';
      case yueHk:
        return '\u{5EE3}\u{6771}\u{8A71} (HK)';
      case swKe:
        return 'Kiswahili (Kenya)';
    }
  }

  /// BCP 47 tag (e.g. "en-US", "zh-Hant-HK").
  String get bcp47 {
    switch (this) {
      case enUs:
        return 'en-US';
      case frFr:
        return 'fr-FR';
      case nlNl:
        return 'nl-NL';
      case deDe:
        return 'de-DE';
      case esEs:
        return 'es-ES';
      case zhHantHk:
        return 'zh-Hant-HK';
      case yueHk:
        return 'yue-HK';
      case swKe:
        return 'sw-KE';
    }
  }

  /// Parse a BCP 47 string. Falls back to primary language subtag match
  /// when the full tag doesn't match (e.g. "fr-CA" resolves to French).
  static Locale? fromBcp47(String s) {
    final lowered = s.toLowerCase().replaceAll('_', '-');
    // Exact match
    for (final l in values) {
      if (l.bcp47.toLowerCase() == lowered) return l;
    }
    // Primary subtag fallback
    final primary = lowered.split('-').first;
    for (final l in values) {
      if (l.bcp47.toLowerCase().split('-').first == primary) return l;
    }
    return null;
  }
}

/// Dropdown selector for switching between locales.
///
/// Reads and writes a [ValueNotifier<Locale>] so the parent controls
/// the currently selected locale. Mirrors `ur_web_frame::LangSelector`.
class LangSelector extends StatefulWidget {
  final ValueNotifier<Locale> locale;
  final ValueNotifier<String?>? sessionLocale;
  final ValueNotifier<List<Locale>?>? availableLocales;
  final void Function(Locale)? onChange;

  const LangSelector({
    super.key,
    required this.locale,
    this.sessionLocale,
    this.availableLocales,
    this.onChange,
  });

  @override
  State<LangSelector> createState() => _LangSelectorState();
}

class _LangSelectorState extends State<LangSelector> {
  List<Locale> _available = Locale.all;

  @override
  void initState() {
    super.initState();
    widget.availableLocales?.addListener(_onAvailableChange);
    widget.sessionLocale?.addListener(_onSessionLocaleChange);
  }

  @override
  void dispose() {
    widget.availableLocales?.removeListener(_onAvailableChange);
    widget.sessionLocale?.removeListener(_onSessionLocaleChange);
    super.dispose();
  }

  void _onAvailableChange() {
    final list = widget.availableLocales?.value;
    if (list != null) {
      setState(() => _available = list);
    }
  }

  void _onSessionLocaleChange() {
    final code = widget.sessionLocale?.value;
    if (code != null) {
      final parsed = Locale.fromBcp47(code);
      if (parsed != null) {
        widget.locale.value = parsed;
        widget.onChange?.call(parsed);
      }
    }
  }

  void _select(Locale l) {
    widget.locale.value = l;
    widget.onChange?.call(l);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: widget.locale,
      builder: (context, current, _) {
        return PopupMenuButton<Locale>(
          tooltip: '',
          offset: const Offset(0, 40),
          onSelected: _select,
          child: Text('${current.flag} ${current.bcp47}',
              style: TextStyle(fontSize: UrFontSizes.sm)),
          itemBuilder: (_) => _available.map((l) {
            final active = l == current;
            return PopupMenuItem<Locale>(
              value: l,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: UrSpacing.sm),
                  Text(l.label, style: TextStyle(
                    color: active ? null : null,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  )),
                  if (active) ...[
                    const SizedBox(width: UrSpacing.sm),
                    const Text('✓', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
