import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/l10n.dart';

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
        if (_id.text.trim().isEmpty || _pw.text.isEmpty) throw ApiException(context.l10n.errorEnterCredentials);
        final r = await auth.login(_id.text.trim(), _pw.text);
        if (r.needs2fa && mounted) setState(() => _challenge = r.challengeToken);
      });

  @override
  Widget build(BuildContext context) {
    final twoFa = _challenge != null; final l = context.l10n;
    return AuthScaffold(
      title: twoFa ? l.authTwoStepTitle : l.authWelcomeBack,
      subtitle: twoFa ? l.authTwoStepSubtitle : l.authSignInSubtitle,
      children: [
        if (!twoFa) ...[
          TextField(controller: _id, decoration: InputDecoration(labelText: l.fieldEmailOrUsername), keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username], textInputAction: TextInputAction.next),
          const SizedBox(height: Sp.s3),
          TextField(controller: _pw, obscureText: _hide, autofillHints: const [AutofillHints.password], onSubmitted: (_) => _submit(),
              decoration: InputDecoration(labelText: l.fieldPassword, suffixIcon: IconButton(tooltip: _hide ? l.showPassword : l.hidePassword, icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide)))),
          Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(onPressed: () => context.push('/forgot'), child: Text(l.forgotPassword))),
        ] else
          TextField(controller: _code, decoration: InputDecoration(labelText: l.fieldCode), autofocus: true, textDirection: TextDirection.ltr, onSubmitted: (_) => _submit()),
        errorText(context),
        FilledButton(onPressed: busy ? null : _submit, child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(twoFa ? l.verify : l.signIn)),
        if (!twoFa) ...[
          const SizedBox(height: Sp.s3),
          OutlinedButton.icon(onPressed: () => context.push('/phone'), icon: const Icon(Icons.phone_iphone), label: Text(l.continueWithPhone)),
          const SizedBox(height: Sp.s4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(l.newHere, style: TextStyle(color: context.tk.inkMuted)), TextButton(onPressed: () => context.push('/register'), child: Text(l.createAccount))]),
        ] else
          TextButton(onPressed: () => setState(() { _challenge = null; error = null; }), child: Text(l.backToSignIn)),
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
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthScaffold(
        back: true, title: l.registerTitle, subtitle: l.registerSubtitle,
        children: [
          Form(key: _form, child: Column(children: [
            TextFormField(controller: _name, decoration: InputDecoration(labelText: l.fieldDisplayNameOptional)),
            const SizedBox(height: Sp.s3),
            TextFormField(controller: _user, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: l.fieldUsername, helperText: l.usernameHelper), validator: (v) => RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(v ?? '') ? null : l.usernameInvalid),
            const SizedBox(height: Sp.s3),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: l.fieldEmail), validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v ?? '') ? null : l.emailInvalid),
            const SizedBox(height: Sp.s3),
            TextFormField(controller: _pw, obscureText: true, decoration: InputDecoration(labelText: l.fieldPassword, helperText: l.passwordHelper), validator: (v) => (v ?? '').length >= 8 ? null : l.passwordTooShort),
            const SizedBox(height: Sp.s3),
            TextFormField(controller: _ref, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: l.fieldReferralOptional)),
          ])),
          const SizedBox(height: Sp.s4),
          errorText(context),
          FilledButton(onPressed: busy ? null : _submit, child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.createAccount)),
        ],
      );
  }
}

class PhoneScreen extends ConsumerStatefulWidget { const PhoneScreen({super.key}); @override ConsumerState<PhoneScreen> createState() => _PhoneState(); }
class _PhoneState extends ConsumerState<PhoneScreen> with BusyMixin {
  final _phone = TextEditingController(), _code = TextEditingController();
  bool _sent = false; String? _challenge;
  @override
  void dispose() { _phone.dispose(); _code.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthScaffold(
        back: true, title: _sent ? l.phoneTitleEnterCode : l.phoneTitle, subtitle: _sent ? l.phoneCodeSent(isolate(_phone.text)) : l.phoneFormatHint(isolate('+14155550123')),
        children: [
          TextField(controller: _phone, enabled: !_sent, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: l.fieldPhone)),
          if (_sent) ...[const SizedBox(height: Sp.s3), TextField(controller: _code, keyboardType: TextInputType.number, maxLength: _challenge == null ? 6 : 12, autofocus: true, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: _challenge == null ? l.fieldCode : l.field2faCode))],
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
            child: Text(_sent ? l.verify : l.sendCode),
          ),
        ],
      );
  }
}

class ForgotScreen extends ConsumerStatefulWidget { const ForgotScreen({super.key}); @override ConsumerState<ForgotScreen> createState() => _ForgotState(); }
class _ForgotState extends ConsumerState<ForgotScreen> with BusyMixin {
  final _email = TextEditingController(), _code = TextEditingController(), _pw = TextEditingController();
  bool _sent = false;
  @override
  void dispose() { _email.dispose(); _code.dispose(); _pw.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthScaffold(
        back: true, title: l.resetTitle, subtitle: _sent ? l.resetSentSubtitle : l.resetSubtitle,
        children: [
          TextField(controller: _email, enabled: !_sent, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: l.fieldEmail)),
          if (_sent) ...[
            const SizedBox(height: Sp.s3), TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 6, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: l.fieldCode)),
            const SizedBox(height: Sp.s3), TextField(controller: _pw, obscureText: true, decoration: InputDecoration(labelText: l.fieldNewPassword, helperText: l.passwordHelper)),
          ],
          const SizedBox(height: Sp.s3),
          errorText(context),
          FilledButton(
            onPressed: busy ? null : () => run(() async {
              final a = ref.read(authProvider.notifier);
              if (!_sent) { await a.forgot(_email.text.trim().toLowerCase()); setState(() => _sent = true); return; }
              await a.reset(_email.text.trim().toLowerCase(), _code.text.trim(), _pw.text);
              if (context.mounted) { toast(context, l.passwordUpdated); context.go('/login'); }
            }),
            child: Text(_sent ? l.updatePassword : l.sendCode),
          ),
        ],
      );
  }
}
