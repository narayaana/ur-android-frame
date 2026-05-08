import 'package:flutter/material.dart';
import 'tokens.dart';
import 'translations.dart';

/// A user role — machine-readable code and display label (pre-translated by backend).
class RoleInfo {
  final String code;
  final String label;
  const RoleInfo({required this.code, required this.label});

  factory RoleInfo.fromJson(Map<String, dynamic> json) =>
      RoleInfo(code: json['code'] as String, label: json['label'] as String);
}

/// A list of roles from the backend.
class RolesResponse {
  final List<RoleInfo> roles;
  const RolesResponse({required this.roles});

  factory RolesResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['roles'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(RoleInfo.fromJson)
        .toList();
    return RolesResponse(roles: list);
  }
}

/// Renders a horizontal list of role badges (pills).
///
/// Uses the [translations] map to resolve `roles.{code}` keys into localised
/// display names, falling back to the pre-translated [RoleInfo.label].
class RoleBadgeList extends StatelessWidget {
  final List<RoleInfo> roles;
  final ValueNotifier<TranslationMap?>? translations;

  const RoleBadgeList({
    super.key,
    required this.roles,
    this.translations,
  });

  @override
  Widget build(BuildContext context) {
    final tm = translations?.value;
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: UrSpacing.xs,
      runSpacing: 2,
      children: roles.map((r) {
        final key = 'roles.${r.code}';
        final display = tm != null ? tm.get(key) : r.label;
        final label = display == key ? r.label : display;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: UrSpacing.xs + 3, vertical: 1),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.05),
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(UrRadii.sm),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: UrFontSizes.sm - 2, color: cs.onSurface.withValues(alpha: 0.5)),
          ),
        );
      }).toList(),
    );
  }
}
