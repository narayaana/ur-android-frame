import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'config.dart';
import 'tokens.dart';
import 'translations.dart';

// ── Data types ───────────────────────────────────────────────────────────────

class LocalizedNameData {
  final String locale;
  final String value;
  const LocalizedNameData({required this.locale, required this.value});

  factory LocalizedNameData.fromJson(Map<String, dynamic> json) =>
      LocalizedNameData(locale: json['locale'] as String, value: json['value'] as String);
}

class ZoneCountryData {
  final String id;
  final String countryCode;
  final String name;
  final List<LocalizedNameData> localizedNames;
  final String? imageIconUrl;
  final String? stateCode;

  const ZoneCountryData({
    required this.id,
    required this.countryCode,
    required this.name,
    required this.localizedNames,
    this.imageIconUrl,
    this.stateCode,
  });

  factory ZoneCountryData.fromJson(Map<String, dynamic> json) => ZoneCountryData(
    id: json['id'] as String,
    countryCode: json['country_code'] as String,
    name: json['name'] as String,
    localizedNames: (json['localized_names'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>().map(LocalizedNameData.fromJson).toList() ?? [],
    imageIconUrl: json['image_icon_url'] as String?,
    stateCode: json['state_code'] as String?,
  );
}

class ZoneAiData {
  final String id;
  final String code;
  final String name;
  final List<LocalizedNameData> localizedNames;

  const ZoneAiData({
    required this.id,
    required this.code,
    required this.name,
    required this.localizedNames,
  });

  factory ZoneAiData.fromJson(Map<String, dynamic> json) => ZoneAiData(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    localizedNames: (json['localized_names'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>().map(LocalizedNameData.fromJson).toList() ?? [],
  );
}

class ZoneData {
  final String id;
  final String code;
  final String name;
  final List<LocalizedNameData> localizedNames;
  final ZoneCountryData? country;
  final List<ZoneAiData> aiModels;

  const ZoneData({
    required this.id,
    required this.code,
    required this.name,
    required this.localizedNames,
    this.country,
    required this.aiModels,
  });

  factory ZoneData.fromJson(Map<String, dynamic> json) => ZoneData(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    localizedNames: (json['localized_names'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>().map(LocalizedNameData.fromJson).toList() ?? [],
    country: json['country'] != null
        ? ZoneCountryData.fromJson(json['country'] as Map<String, dynamic>)
        : null,
    aiModels: (json['ai_models'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>().map(ZoneAiData.fromJson).toList() ?? [],
  );
}

class GeoFields {
  final String countryCode;
  final String? state;
  final String? city;
  final String? country;

  const GeoFields({required this.countryCode, this.state, this.city, this.country});
}

// ── Zone resource ────────────────────────────────────────────────────────────

class ZoneResource extends ChangeNotifier {
  ZoneData? _zone;
  ZoneData? get zone => _zone;

  Future<void> fetch(GeoFields? key) async {
    if (key == null) {
      _zone = null;
      notifyListeners();
      return;
    }
    final params = <String, String>{};
    if (key.state != null && key.state!.isNotEmpty) params['state'] = key.state!;
    if (key.city != null && key.city!.isNotEmpty) params['city'] = key.city!;
    if (key.country != null && key.country!.isNotEmpty) params['country'] = key.country!;

    final uri = Uri.parse('${UrConfig.baseUrl}/zones/by-country/${key.countryCode}')
        .replace(queryParameters: params.isNotEmpty ? params : null);

    try {
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        _zone = ZoneData.fromJson(jsonDecode(resp.body));
      } else {
        _zone = null;
      }
    } catch (_) {
      _zone = null;
    }
    notifyListeners();
  }
}

// ── Detect state ─────────────────────────────────────────────────────────────

enum DetectState { loading, detected, error }

// ── ZoneDetector ─────────────────────────────────────────────────────────────

class ZoneDetector extends StatefulWidget {
  final ValueNotifier<String?> countryCode;
  final ValueNotifier<String?> detectedState;
  final ValueNotifier<String?>? detectedCity;
  final ValueNotifier<String?>? detectedCountry;
  final ValueNotifier<String?>? gpsGeocodeUrl;
  final ValueNotifier<String?>? ipGeolocationUrl;
  final ValueNotifier<TranslationMap?>? translations;

  const ZoneDetector({
    super.key,
    required this.countryCode,
    required this.detectedState,
    this.detectedCity,
    this.detectedCountry,
    this.gpsGeocodeUrl,
    this.ipGeolocationUrl,
    this.translations,
  });

  @override
  State<ZoneDetector> createState() => _ZoneDetectorState();
}

class _ZoneDetectorState extends State<ZoneDetector> {
  final _state = ValueNotifier<DetectState>(DetectState.loading);
  final _zoneResource = ZoneResource();

  @override
  void initState() {
    super.initState();
    _startDetection();
  }

  @override
  void dispose() {
    _state.dispose();
    _zoneResource.dispose();
    super.dispose();
  }

  String get _gpsUrl => widget.gpsGeocodeUrl?.value ?? '${UrConfig.baseUrl}/geo/reverse?lat={lat}&lon={lon}';
  String get _ipUrl => widget.ipGeolocationUrl?.value ?? '${UrConfig.baseUrl}/geo/ip';

  Future<void> _startDetection() async {
    try {
      final pos = await _tryGps();
      if (pos == null) { await _ipFallback(); return; }

      final gf = await _reverseGeocode(pos.$1, pos.$2);
      if (gf != null) {
        _applyResult(gf);
      } else {
        await _ipFallback();
      }
    } catch (_) {
      await _ipFallback();
    }
  }

  /// Returns (lat, lon) from GPS, or null if unavailable/denied.
  Future<(double, double)?> _tryGps() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5),
        ),
      );
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<GeoFields?> _reverseGeocode(double lat, double lon) async {
    final url = _gpsUrl
        .replaceAll('{lat}', lat.toString())
        .replaceAll('{lon}', lon.toString());
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;

      // Nominatim format
      final addr = json['address'] as Map<String, dynamic>?;
      if (addr != null && addr['country_code'] != null) {
        return GeoFields(
          countryCode: (addr['country_code'] as String).toUpperCase(),
          state: addr['state'] as String?,
          city: addr['city'] as String?,
          country: addr['country'] as String?,
        );
      }

      // Photon GeoJSON format
      final features = json['features'] as List<dynamic>?;
      if (features != null && features.isNotEmpty) {
        final props = (features.first as Map<String, dynamic>)['properties'] as Map<String, dynamic>?;
        if (props != null && props['countrycode'] != null) {
          return GeoFields(
            countryCode: (props['countrycode'] as String).toUpperCase(),
            state: props['state'] as String?,
            city: props['city'] as String?,
            country: props['country'] as String?,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _ipFallback() async {
    try {
      final resp = await http.get(Uri.parse(_ipUrl));
      if (resp.statusCode != 200) { _state.value = DetectState.error; return; }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final cc = (json['country_code'] ?? json['country']) as String?;
      if (cc == null) { _state.value = DetectState.error; return; }
      _applyResult(GeoFields(
        countryCode: cc.toUpperCase(),
        state: json['region'] as String?,
        city: json['city'] as String?,
        country: json['country_name'] as String?,
      ));
    } catch (_) {
      _state.value = DetectState.error;
    }
  }

  void _applyResult(GeoFields gf) {
    widget.countryCode.value = gf.countryCode;
    widget.detectedState.value = gf.state;
    widget.detectedCity?.value = gf.city;
    widget.detectedCountry?.value = gf.country;
    _state.value = DetectState.detected;
    _zoneResource.fetch(gf);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DetectState>(
      valueListenable: _state,
      builder: (context, st, _) {
        switch (st) {
          case DetectState.loading:
            final tm = widget.translations?.value;
            final label = tm?.get('zone.detecting') ?? 'Detecting location...';
            final display = label == 'zone.detecting' ? 'Detecting location...' : label;
            return Text(display, style: TextStyle(
              fontSize: UrFontSizes.sm,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ));

          case DetectState.detected:
            final cc = widget.countryCode.value ?? '';
            final name = _zoneResource.zone?.name ?? cc;
            final cs = Theme.of(context).colorScheme;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: TextStyle(
                  fontSize: UrFontSizes.sm,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                )),
                if (cc.isNotEmpty) ...[
                  const SizedBox(width: UrSpacing.xs),
                  Text(cc, style: TextStyle(fontSize: UrFontSizes.sm - 2, color: cs.onSurface.withValues(alpha: 0.4))),
                ],
              ],
            );

          case DetectState.error:
            return const SizedBox(width: 4, height: 4);
        }
      },
    );
  }
}

// ── ZoneAiList ───────────────────────────────────────────────────────────────

class ZoneAiList extends StatefulWidget {
  final ValueNotifier<String?>? countryCode;
  final ValueNotifier<String?>? state;
  final ValueNotifier<String?>? city;
  final ValueNotifier<String?>? country;
  final ValueNotifier<String?>? gpsGeocodeUrl;
  final ValueNotifier<String?>? ipGeolocationUrl;
  final ValueNotifier<TranslationMap?>? translations;
  final ValueNotifier<String>? locale;

  const ZoneAiList({
    super.key,
    this.countryCode,
    this.state,
    this.city,
    this.country,
    this.gpsGeocodeUrl,
    this.ipGeolocationUrl,
    this.translations,
    this.locale,
  });

  @override
  State<ZoneAiList> createState() => _ZoneAiListState();
}

class _ZoneAiListState extends State<ZoneAiList> {
  final _zoneResource = ZoneResource();
  GeoFields? _lastKey;

  @override
  void initState() {
    super.initState();
    widget.countryCode?.addListener(_onKeyChange);
    widget.state?.addListener(_onKeyChange);
    widget.city?.addListener(_onKeyChange);
    widget.country?.addListener(_onKeyChange);
    _maybeFetch();
  }

  @override
  void dispose() {
    widget.countryCode?.removeListener(_onKeyChange);
    widget.state?.removeListener(_onKeyChange);
    widget.city?.removeListener(_onKeyChange);
    widget.country?.removeListener(_onKeyChange);
    _zoneResource.dispose();
    super.dispose();
  }

  void _onKeyChange() => _maybeFetch();

  void _maybeFetch() {
    final cc = widget.countryCode?.value;
    if (cc == null || cc.isEmpty) return;
    final key = GeoFields(
      countryCode: cc,
      state: widget.state?.value,
      city: widget.city?.value,
      country: widget.country?.value,
    );
    if (_lastKey != null &&
        _lastKey!.countryCode == key.countryCode &&
        _lastKey!.state == key.state &&
        _lastKey!.city == key.city &&
        _lastKey!.country == key.country) return;
    _lastKey = key;
    _zoneResource.fetch(key);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _zoneResource,
      builder: (context, _) {
        final z = _zoneResource.zone;
        if (z == null) return const SizedBox.shrink();

        final cs = Theme.of(context).colorScheme;

        if (z.aiModels.isEmpty) {
          final tm = widget.translations?.value;
          final raw = tm?.get('zone.no_ai_models') ?? 'No AI models available';
          final display = raw == 'zone.no_ai_models' ? 'No AI models available' : raw;
          return Text(display, style: TextStyle(
            fontSize: UrFontSizes.sm,
            color: cs.onSurface.withValues(alpha: 0.5),
            fontStyle: FontStyle.italic,
          ));
        }

        final loc = widget.locale?.value ?? 'en-US';
        return Wrap(
          spacing: UrSpacing.xs,
          runSpacing: 2,
          children: z.aiModels.map((ai) {
            final displayName = ai.localizedNames
                .where((ln) => ln.locale == loc)
                .map((ln) => ln.value)
                .firstOrNull ?? ai.name;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: UrSpacing.sm, vertical: 1),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.05),
                border: Border.all(color: cs.outline),
                borderRadius: BorderRadius.circular(UrRadii.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(displayName, style: TextStyle(
                    fontSize: UrFontSizes.sm,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  )),
                  const SizedBox(width: UrSpacing.xs),
                  Text(ai.code, style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.4),
                    fontFamily: 'monospace',
                  )),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
