import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.children, this.back = false});
  final String title, subtitle; final List<Widget> children; final bool back;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: back ? AppBar() : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Sp.s6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!back) Padding(padding: const EdgeInsets.only(bottom: Sp.s6), child: Text('Jeyabo', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: context.tk.brand))),
                  Text(title, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: Sp.s2),
                  Text(subtitle, style: TextStyle(color: context.tk.inkMuted)),
                  const SizedBox(height: Sp.s6),
                  ...children,
                ]),
              ),
            ),
          ),
        ),
      );
}

mixin BusyMixin<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? error;
  /// Runs [f], shows the error inline instead of throwing, and prevents double submits.
  Future<void> run(Future<void> Function() f) async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try { await f(); } on ApiException catch (e) { if (mounted) setState(() => error = e.message); } catch (e) { if (mounted) setState(() => error = e.toString()); } finally { if (mounted) setState(() => busy = false); }
  }
  Widget errorText(BuildContext c) => error == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: Sp.s3), child: Row(children: [Icon(Icons.error_outline, size: 18, color: c.tk.danger), const SizedBox(width: Sp.s2), Expanded(child: Text(error!, style: TextStyle(color: c.tk.danger)))]));
}

class LoginScreen extends ConsumerStatefulWidget { const LoginScreen({super.key}); @override ConsumerState<LoginScreen> createState() => _LoginState(); }
class _LoginState extends ConsumerState<LoginScreen> with BusyMixin {
  final _id = TextEditingController(), _pw = TextEditingController(), _code = TextEditingController();
  String? _challenge; bool _hide = true;
  @override
  void dispose() { _id.dispose(); _pw.dispose(); _code.dispose(); super.dispose(); }

  Future<void> _submit() => run(() async {
        final auth = ref.read(authProvider.notifier);
        if (_challenge != null) { await auth.verify2fa(_challenge!, _code.text.trim()); return; }
        if (_id.text.trim().isEmpty || _pw.text.isEmpty) throw ApiException('Enter your email or username and password');
        final r = await auth.login(_id.text.trim(), _pw.text);
        if (r.needs2fa && mounted) setState(() => _challenge = r.challengeToken);
      });

  @override
  Widget build(BuildContext context) {
    final twoFa = _challenge != null;
    return AuthScaffold(
      title: twoFa ? 'Two-step check' : 'Welcome back',
      subtitle: twoFa ? 'Enter the 6-digit code from your authenticator app, or a backup code.' : 'Sign in to see what your friends are up to.',
      children: [
        if (!twoFa) ...[
          TextField(controller: _id, decoration: const InputDecoration(labelText: 'Email or username'), keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username], textInputAction: TextInputAction.next),
          const SizedBox(height: Sp.s3),
          TextField(controller: _pw, obscureText: _hide, autofillHints: const [AutofillHints.password], onSubmitted: (_) => _submit(),
              decoration: InputDecoration(labelText: 'Password', suffixIcon: IconButton(tooltip: _hide ? 'Show password' : 'Hide password', icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide)))),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.push('/forgot'), child: const Text('Forgot password?'))),
        ] else
          TextField(controller: _code, decoration: const InputDecoration(labelText: 'Code'), autofocus: true, onSubmitted: (_) => _submit()),
        errorText(context),
        FilledButton(onPressed: busy ? null : _submit, child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(twoFa ? 'Verify' : 'Sign in')),
        if (!twoFa) ...[
          const SizedBox(height: Sp.s3),
          OutlinedButton.icon(onPressed: () => context.push('/phone'), icon: const Icon(Icons.phone_iphone), label: const Text('Continue with phone')),
          const SizedBox(height: Sp.s4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('New here?', style: TextStyle(color: context.tk.inkMuted)), TextButton(onPressed: () => context.push('/register'), child: const Text('Create account'))]),
        ] else
          TextButton(onPressed: () => setState(() { _challenge = null; error = null; }), child: const Text('Back to sign in')),
      ],
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget { const RegisterScreen({super.key}); @override ConsumerState<RegisterScreen> createState() => _RegisterState(); }
class _RegisterState extends ConsumerState<RegisterScreen> with BusyMixin {
  final _email = TextEditingController(), _user = TextEditingController(), _name = TextEditingController(), _pw = TextEditingController(), _ref = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() { for (final c in [_email, _user, _name, _pw, _ref]) { c.dispose(); } super.dispose(); }

  Future<void> _submit() { if (!_form.currentState!.validate()) return Future.value(); return run(() async { await ref.read(authProvider.notifier).register(email: _email.text.trim(), username: _user.text.trim(), password: _pw.text, displayName: _name.text.trim(), referral: _ref.text.trim()); }); }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        back: true, title: 'Create your account', subtitle: 'Join the community. It takes a minute.',
        children: [
          Form(key: _form, child: Column(children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Display name (optional)')),
            const SizedBox(height: Sp.s3),
            TextFormField(controller: _user, decoration: const InputDecoration(labelText: 'Username', helperText: '3-30 letters, numbers or _'), validator: (v) => RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(v ?? '') ? null : 'Use 3-30 letters, numbers or _'),
            const SizedBox(height: Sp.s3),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v ?? '') ? null : 'Enter a valid email'),
            const SizedBox(height: Sp.s3),
            TextFormField(controller: _pw, obscureText: true, decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 8 characters'), validator: (v) => (v ?? '').length >= 8 ? null : 'At least 8 characters'),
            const SizedBox(height: Sp.s3),
            TextFormField(controller: _ref, decoration: const InputDecoration(labelText: 'Referral code (optional)')),
          ])),
          const SizedBox(height: Sp.s4),
          errorText(context),
          FilledButton(onPressed: busy ? null : _submit, child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create account')),
        ],
      );
}

class PhoneScreen extends ConsumerStatefulWidget { const PhoneScreen({super.key}); @override ConsumerState<PhoneScreen> createState() => _PhoneState(); }
class _PhoneState extends ConsumerState<PhoneScreen> with BusyMixin {
  final _phone = TextEditingController(), _code = TextEditingController();
  bool _sent = false; String? _challenge;
  @override
  void dispose() { _phone.dispose(); _code.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        back: true, title: _sent ? 'Enter the code' : 'Your phone number', subtitle: _sent ? 'We sent a 6-digit code to ${_phone.text}.' : 'Use international format, e.g. +14155550123.',
        children: [
          TextField(controller: _phone, enabled: !_sent, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
          if (_sent) ...[const SizedBox(height: Sp.s3), TextField(controller: _code, keyboardType: TextInputType.number, maxLength: _challenge == null ? 6 : 12, autofocus: true, decoration: InputDecoration(labelText: _challenge == null ? 'Code' : '2FA code'))],
          const SizedBox(height: Sp.s3),
          errorText(context),
          FilledButton(
            onPressed: busy ? null : () => run(() async {
              final a = ref.read(authProvider.notifier);
              if (!_sent) { await a.requestOtp(_phone.text.trim()); setState(() => _sent = true); return; }
              if (_challenge != null) { await a.verify2fa(_challenge!, _code.text.trim()); if (context.mounted) context.go('/'); return; }
              final r = await a.verifyOtp(_phone.text.trim(), _code.text.trim());
              if (r.needs2fa) { setState(() { _challenge = r.challengeToken; _code.clear(); }); } else if (context.mounted) { context.go('/'); }
            }),
            child: Text(_sent ? 'Verify' : 'Send code'),
          ),
        ],
      );
}

class ForgotScreen extends ConsumerStatefulWidget { const ForgotScreen({super.key}); @override ConsumerState<ForgotScreen> createState() => _ForgotState(); }
class _ForgotState extends ConsumerState<ForgotScreen> with BusyMixin {
  final _email = TextEditingController(), _code = TextEditingController(), _pw = TextEditingController();
  bool _sent = false;
  @override
  void dispose() { _email.dispose(); _code.dispose(); _pw.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        back: true, title: 'Reset password', subtitle: _sent ? 'If that email has an account, a code is on its way.' : 'We will email you a 6-digit code.',
        children: [
          TextField(controller: _email, enabled: !_sent, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          if (_sent) ...[
            const SizedBox(height: Sp.s3), TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Code')),
            const SizedBox(height: Sp.s3), TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(labelText: 'New password', helperText: 'At least 8 characters')),
          ],
          const SizedBox(height: Sp.s3),
          errorText(context),
          FilledButton(
            onPressed: busy ? null : () => run(() async {
              final a = ref.read(authProvider.notifier);
              if (!_sent) { await a.forgot(_email.text.trim().toLowerCase()); setState(() => _sent = true); return; }
              await a.reset(_email.text.trim().toLowerCase(), _code.text.trim(), _pw.text);
              if (context.mounted) { toast(context, 'Password updated. Sign in with your new password.'); context.go('/login'); }
            }),
            child: Text(_sent ? 'Update password' : 'Send code'),
          ),
        ],
      );
}
