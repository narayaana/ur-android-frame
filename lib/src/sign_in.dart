import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
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

/// Renders the user's name when signed in, or a "Sign in" button when not.
///
/// When [canSignIn] is false (RBAC blocked), renders nothing.
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
        if (current != null) {
          return Text(
            current.username,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE4E4F0),
              decoration: TextDecoration.underline,
              decorationColor: const Color(0x38E4E4F0),
              decorationStyle: TextDecorationStyle.dotted,
              decorationThickness: 1.0,
            ),
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: canSignIn,
          builder: (context, can, _) {
            if (!can) return const SizedBox.shrink();
            final tm = translations?.value;
            final label = tm?.get('sign_in.link') ?? 'Sign-in';
            final display = label == 'sign_in.link' ? 'Sign-in' : label;
            return TextButton(
              onPressed: () => modalOpen.value = true,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(display, style: TextStyle(fontSize: UrFontSizes.sm, color: const Color(0x80E4E4F0))),
            );
          },
        );
      },
    );
  }
}

/// Sign-out button that clears the session and bumps a role-refresh counter.
class SignOutLink extends StatelessWidget {
  final ValueNotifier<SessionInfo?> session;
  final ValueNotifier<int>? roleRefresh;
  final ValueNotifier<TranslationMap?>? translations;

  const SignOutLink({
    super.key,
    required this.session,
    this.roleRefresh,
    this.translations,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionInfo?>(
      valueListenable: session,
      builder: (context, current, _) {
        if (current == null) return const SizedBox.shrink();

        final tm = translations?.value;
        final label = tm?.get('sign_out.link') ?? 'Sign out';
        final display = label == 'sign_out.link' ? 'Sign out' : label;

        return OutlinedButton(
          onPressed: () => _signOut(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: UrSpacing.sm, vertical: UrSpacing.xs),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: const BorderSide(color: Color(0x1AE4E4F0)),
          ),
          child: Text(display, style: TextStyle(fontSize: UrFontSizes.sm, color: const Color(0x80E4E4F0))),
        );
      },
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await http.post(Uri.parse('${UrConfig.baseUrl}/auth/sign-out'));
    } catch (_) {}
    session.value = null;
    roleRefresh?.value += 1;
  }
}

/// Modal sign-in form — username/password with show/hide toggle.
///
/// POSTs to `/auth/sign-in` and updates [session] on success.
class SignInModal extends StatefulWidget {
  final ValueNotifier<bool> open;
  final ValueNotifier<SessionInfo?> session;

  const SignInModal({
    super.key,
    required this.open,
    required this.session,
  });

  @override
  State<SignInModal> createState() => _SignInModalState();
}

class _SignInModalState extends State<SignInModal> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final resp = await http.post(
        Uri.parse('${UrConfig.baseUrl}/auth/sign-in'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _usernameCtrl.text, 'password': _passwordCtrl.text}),
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final info = SessionInfo.fromJson(jsonDecode(resp.body));
        widget.session.value = info;
        widget.open.value = false;
        _usernameCtrl.clear();
        _passwordCtrl.clear();
      } else {
        String msg;
        try {
          msg = jsonDecode(resp.body)['error'] as String? ?? resp.body;
        } catch (_) {
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.open,
      builder: (context, open, _) {
        if (!open) return const SizedBox.shrink();

        return Stack(
          children: [
            // Backdrop
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  widget.open.value = false;
                  setState(() => _error = null);
                },
                child: Container(color: Colors.black54),
              ),
            ),
            // Modal
            Positioned(
              top: UrSpacing.lg + UrSpacing.md,
              right: UrSpacing.md,
              width: 340,
              child: Material(
                color: const Color(0xFF13131F),
                borderRadius: BorderRadius.circular(UrRadii.lg),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(UrSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sign in',
                              style: TextStyle(fontSize: UrFontSizes.lg, fontWeight: FontWeight.w700, color: Color(0xFFE4E4F0))),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            splashRadius: 14,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              widget.open.value = false;
                              setState(() => _error = null);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: UrSpacing.md),
                      // Username
                      TextField(
                        controller: _usernameCtrl,
                        enabled: !_submitting,
                        decoration: const InputDecoration(labelText: 'Username'),
                        style: const TextStyle(color: Color(0xFFE4E4F0)),
                      ),
                      const SizedBox(height: UrSpacing.sm),
                      // Password
                      TextField(
                        controller: _passwordCtrl,
                        enabled: !_submitting,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                            splashRadius: 14,
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        style: const TextStyle(color: Color(0xFFE4E4F0)),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: UrSpacing.sm),
                        Text(_error!, style: const TextStyle(color: Color(0xFFFF5050), fontSize: UrFontSizes.sm)),
                      ],
                      const SizedBox(height: UrSpacing.md),
                      // Submit
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0x403C8CDC),
                            foregroundColor: const Color(0xFFE4E4F0),
                            side: const BorderSide(color: Color(0x7364AAFF)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UrRadii.sm + 1)),
                          ),
                          child: Text(_submitting ? 'Signing in...' : 'Sign in'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
