import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'locale.dart';
import 'tokens.dart';
import 'translations.dart';

/// Session info returned from the backend after sign-in or session check.
class SessionInfo {
  final String username;
  final String id;
  const SessionInfo({required this.username, required this.id});

  factory SessionInfo.fromJson(Map<String, dynamic> json) =>
      SessionInfo(username: json['username'] as String, id: json['id'] as String);
}

// ── Helpers ─────────────────────────────────────────────────────

String _tr(TranslationMap? tm, String key, String fallback) {
  final v = tm?.get(key) ?? key;
  return v == key ? fallback : v;
}

// ── SignInLink ──────────────────────────────────────────────────

class SignInLink extends StatelessWidget {
  final ValueNotifier<SessionInfo?> session;
  final ValueNotifier<bool> canSignIn;
  final ValueNotifier<bool> modalOpen;
  final ValueNotifier<TranslationMap?>? translations;

  const SignInLink({
    super.key,
    required this.session,
    required this.canSignIn,
    required this.modalOpen,
    this.translations,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionInfo?>(
      valueListenable: session,
      builder: (context, current, _) {
        final cs = Theme.of(context).colorScheme;
        if (current != null) {
          return Text(current.username,
              style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface,
                  decoration: TextDecoration.underline,
                  decorationColor: cs.outlineVariant,
                  decorationStyle: TextDecorationStyle.dotted,
                  decorationThickness: 1.0));
        }
        return ValueListenableBuilder<bool>(
          valueListenable: canSignIn,
          builder: (context, can, _) {
            if (!can) return const SizedBox.shrink();
            final label = _tr(translations?.value, 'sign_in.link', 'Sign-in');
            return TextButton(
              onPressed: () => modalOpen.value = true,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(label, style: TextStyle(fontSize: UrFontSizes.sm,
                  color: cs.onSurface.withValues(alpha: 0.5))),
            );
          },
        );
      },
    );
  }
}

// ── SignOutLink ─────────────────────────────────────────────────

class SignOutLink extends StatelessWidget {
  final ValueNotifier<SessionInfo?> session;
  final ValueNotifier<int>? roleRefresh;
  final ValueNotifier<TranslationMap?>? translations;

  const SignOutLink({super.key, required this.session, this.roleRefresh, this.translations});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionInfo?>(
      valueListenable: session,
      builder: (context, current, _) {
        if (current == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final label = _tr(translations?.value, 'sign_out.link', 'Sign out');
        return OutlinedButton(
          onPressed: () => _signOut(context),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: UrSpacing.sm, vertical: UrSpacing.xs),
              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: cs.outline)),
          child: Text(label, style: TextStyle(fontSize: UrFontSizes.sm,
              color: cs.onSurface.withValues(alpha: 0.5))),
        );
      },
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try { await http.post(Uri.parse('${UrConfig.baseUrl}/auth/sign-out')); } catch (_) {}
    session.value = null;
    roleRefresh?.value += 1;
  }
}

// ── SignInModal (multi-mode) ────────────────────────────────────

enum _AuthMode { signIn, register, registerConfirm }

class SignInModal extends StatefulWidget {
  final ValueNotifier<bool> open;
  final ValueNotifier<SessionInfo?> session;
  final ValueNotifier<TranslationMap?>? translations;
  final ValueNotifier<String>? locale;
  final ValueNotifier<List<Locale>?>? availableLocales;

  const SignInModal({
    super.key,
    required this.open,
    required this.session,
    this.translations,
    this.locale,
    this.availableLocales,
  });

  @override
  State<SignInModal> createState() => _SignInModalState();
}

class _SignInModalState extends State<SignInModal> {
  _AuthMode _mode = _AuthMode.signIn;
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _confirmCodeCtrl = TextEditingController();
  String _regLocale = 'en-US';
  String? _regToken;
  String? _message;
  bool _obscure = true;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    _confirmCodeCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    _mode = _AuthMode.signIn;
    _usernameCtrl.clear();
    _passwordCtrl.clear();
    _emailCtrl.clear();
    _confirmCodeCtrl.clear();
    _regLocale = widget.locale?.value ?? 'en-US';
    _regToken = null;
    _message = null;
    _error = null;
    _submitting = false;
  }

  TranslationMap? get _tm => widget.translations?.value;

  // ── Sign in ────────────────────────────────────────────────
  Future<void> _signIn() async {
    if (_submitting) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final resp = await http.post(Uri.parse('${UrConfig.baseUrl}/auth/sign-in'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': _usernameCtrl.text, 'password': _passwordCtrl.text}));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final info = SessionInfo.fromJson(jsonDecode(resp.body));
        widget.session.value = info;
        widget.open.value = false;
        _usernameCtrl.clear();
        _passwordCtrl.clear();
      } else {
        String msg;
        try { msg = jsonDecode(resp.body)['error'] as String? ?? resp.body; } catch (_) {
          msg = resp.body.isNotEmpty ? resp.body : 'Sign-in failed';
        }
        setState(() => _error = msg);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Register ────────────────────────────────────────────────
  Future<void> _register() async {
    if (_submitting) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final resp = await http.post(Uri.parse('${UrConfig.baseUrl}/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': _usernameCtrl.text, 'email': _emailCtrl.text,
            'password': _passwordCtrl.text, 'locale': _regLocale,
          }));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _regToken = body['token'] as String?;
        _message = body['message'] as String?;
        setState(() { _mode = _AuthMode.registerConfirm; _error = null; });
      } else {
        String msg;
        try { msg = jsonDecode(resp.body)['error'] as String? ?? resp.body; } catch (_) {
          msg = resp.body.isNotEmpty ? resp.body : 'Registration failed';
        }
        setState(() => _error = msg);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Confirm ────────────────────────────────────────────────
  Future<void> _confirm() async {
    if (_submitting || _regToken == null) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final resp = await http.post(Uri.parse('${UrConfig.baseUrl}/auth/register/confirm'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': _regToken, 'code': _confirmCodeCtrl.text}));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final info = SessionInfo.fromJson(jsonDecode(resp.body));
        widget.session.value = info;
        widget.open.value = false;
      } else {
        String msg;
        try { msg = jsonDecode(resp.body)['error'] as String? ?? resp.body; } catch (_) {
          msg = resp.body.isNotEmpty ? resp.body : 'Confirmation failed';
        }
        setState(() => _error = msg);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.open,
      builder: (context, open, _) {
        if (!open) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final tm = _tm;

        return Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () { widget.open.value = false; _reset(); },
              child: Container(color: Colors.black54),
            ),
          ),
          Positioned(
            top: UrSpacing.lg + UrSpacing.md, right: UrSpacing.md, width: 340,
            child: Material(
              color: cs.surface, borderRadius: BorderRadius.circular(UrRadii.lg), elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(UrSpacing.lg),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_title(tm), style: TextStyle(fontSize: UrFontSizes.lg,
                          fontWeight: FontWeight.w700, color: cs.onSurface)),
                      IconButton(icon: Icon(Icons.close, size: 18, color: cs.onSurface),
                          splashRadius: 14, padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () { widget.open.value = false; _reset(); }),
                    ]),
                    const SizedBox(height: UrSpacing.md),

                    // ── Sign-in form ──────────────────────────
                    if (_mode == _AuthMode.signIn) ...[
                      _buildUsername(cs),
                      const SizedBox(height: UrSpacing.sm),
                      _buildPassword(cs, onSubmitted: (_) => _signIn()),
                      if (_error != null) ...[
                        const SizedBox(height: UrSpacing.sm),
                        Text(_error!, style: TextStyle(color: cs.error, fontSize: UrFontSizes.sm)),
                      ],
                      const SizedBox(height: UrSpacing.md),
                      _buildButton(cs, _signIn,
                          _tr(tm, 'sign_in.submit', 'Sign in'),
                          _tr(tm, 'sign_in.signing_in', 'Signing in...')),
                      _buildSwitchLink(
                          _tr(tm, 'sign_in.register_link', 'Create account'),
                          () => setState(() { _mode = _AuthMode.register; _error = null; })),
                    ],

                    // ── Register form ─────────────────────────
                    if (_mode == _AuthMode.register) ...[
                      _buildUsername(cs),
                      const SizedBox(height: UrSpacing.sm),
                      _buildEmail(cs),
                      const SizedBox(height: UrSpacing.sm),
                      _buildPassword(cs, onSubmitted: (_) => _register()),
                      const SizedBox(height: UrSpacing.sm),
                      _buildLocaleDropdown(cs),
                      if (_error != null) ...[
                        const SizedBox(height: UrSpacing.sm),
                        Text(_error!, style: TextStyle(color: cs.error, fontSize: UrFontSizes.sm)),
                      ],
                      const SizedBox(height: UrSpacing.md),
                      _buildButton(cs, _register,
                          _tr(tm, 'register.submit', 'Register'),
                          _tr(tm, 'register.registering', 'Registering...')),
                      _buildSwitchLink(
                          _tr(tm, 'register.sign_in_link', 'Already have an account? Sign in'),
                          () => setState(() { _mode = _AuthMode.signIn; _error = null; })),
                    ],

                    // ── Confirm form ──────────────────────────
                    if (_mode == _AuthMode.registerConfirm) ...[
                      if (_message != null)
                        Padding(padding: const EdgeInsets.only(bottom: UrSpacing.sm),
                            child: Text(_message!, style: TextStyle(color: cs.onSurface,
                                fontSize: UrFontSizes.sm))),
                      TextField(
                        controller: _confirmCodeCtrl, enabled: !_submitting,
                        decoration: InputDecoration(
                            labelText: _tr(tm, 'register_confirm.code', 'Confirmation code')),
                        style: TextStyle(color: cs.onSurface),
                        onSubmitted: (_) => _confirm(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: UrSpacing.sm),
                        Text(_error!, style: TextStyle(color: cs.error, fontSize: UrFontSizes.sm)),
                      ],
                      const SizedBox(height: UrSpacing.md),
                      _buildButton(cs, _confirm,
                          _tr(tm, 'register_confirm.submit', 'Confirm'),
                          _tr(tm, 'register_confirm.confirming', 'Confirming...')),
                      _buildSwitchLink(
                          _tr(tm, 'register_confirm.back', 'Back to registration'),
                          () => setState(() { _mode = _AuthMode.register; _error = null; })),
                    ],
                  ]),
              ),
            ),
          ),
        ]);
      },
    );
  }

  String _title(TranslationMap? tm) {
    switch (_mode) {
      case _AuthMode.register: return _tr(tm, 'register.title', 'Create account');
      case _AuthMode.registerConfirm: return _tr(tm, 'register_confirm.title', 'Confirm your account');
      case _AuthMode.signIn: return _tr(tm, 'sign_in.title', 'Sign in');
    }
  }

  Widget _buildUsername(ColorScheme cs) {
    final tm = _tm;
    return TextField(
      controller: _usernameCtrl, enabled: !_submitting,
      decoration: InputDecoration(labelText: _tr(tm, 'sign_in.username', 'Username')),
      style: TextStyle(color: cs.onSurface),
    );
  }

  Widget _buildEmail(ColorScheme cs) {
    final tm = _tm;
    return TextField(
      controller: _emailCtrl, enabled: !_submitting, keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(labelText: _tr(tm, 'register.email', 'Email')),
      style: TextStyle(color: cs.onSurface),
    );
  }

  Widget _buildPassword(ColorScheme cs, {ValueChanged<String>? onSubmitted}) {
    return TextField(
      controller: _passwordCtrl, enabled: !_submitting, obscureText: _obscure,
      decoration: InputDecoration(
        labelText: _tr(_tm, 'sign_in.password', 'Password'),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18),
          splashRadius: 14,
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      style: TextStyle(color: cs.onSurface),
      onSubmitted: onSubmitted,
    );
  }

  Widget _buildLocaleDropdown(ColorScheme cs) {
    final locales = widget.availableLocales?.value ?? [Locale.enUs];
    return DropdownButtonFormField<String>(
      value: _regLocale,
      decoration: InputDecoration(labelText: _tr(_tm, 'register.locale', 'Language')),
      style: TextStyle(color: cs.onSurface, fontSize: UrFontSizes.sm),
      items: locales.map((l) => DropdownMenuItem(value: l.bcp47,
          child: Text(l.label, style: TextStyle(fontSize: UrFontSizes.sm)))).toList(),
      onChanged: _submitting ? null : (v) => setState(() => _regLocale = v ?? 'en-US'),
    );
  }

  Widget _buildButton(ColorScheme cs, VoidCallback onPressed, String label, String loading) {
    return SizedBox(width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary.withValues(alpha: 0.25),
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.primary.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UrRadii.sm + 1)),
        ),
        child: Text(_submitting ? loading : label),
      ),
    );
  }

  Widget _buildSwitchLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: UrSpacing.sm),
      child: Align(
        alignment: Alignment.center,
        child: TextButton(
          onPressed: _submitting ? null : onTap,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Text(label, style: TextStyle(fontSize: UrFontSizes.sm,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
        ),
      ),
    );
  }
}
