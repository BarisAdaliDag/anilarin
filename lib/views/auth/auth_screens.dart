import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../view_model/app_view_model.dart';

/// Oturum yoksa giriş / kayıt ekranını açar; giriş yapılırsa true döner.
Future<bool> ensureSignedIn(BuildContext context) async {
  final auth = context.read<AuthService>();
  if (!auth.available || auth.signedIn) return true;
  final ok = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AuthScreen(forCheckout: true)));
  return ok ?? false;
}

/// E-posta ile giriş ve kayıt. İlk açılışta "Şimdilik Geç" ile atlanabilir; siparişte zorunludur.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.forCheckout = false, this.onSkip});

  final bool forCheckout;

  /// İlk açılışta gösterilir; null ise "Şimdilik Geç" yok.
  final VoidCallback? onSkip;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _profile = UserProfile();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = true;
  bool _kvkk = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_register && !_kvkk) return setState(() => _error = S.kvkkRequired);
    _form.currentState!.save();
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthService>();
    final nav = Navigator.of(context);
    try {
      if (_register) {
        _profile.email = _email.text.trim();
        await auth.register(_profile, _password.text);
      } else {
        await auth.signIn(_email.text.trim(), _password.text);
      }
      if (nav.canPop()) nav.pop(true);
    } on AuthError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) return setState(() => _error = S.authInvalidEmail);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthService>().resetPassword(email);
      messenger.showSnackBar(const SnackBar(content: Text(S.resetSent)));
    } on AuthError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
    String? required(String? v) => v == null || v.trim().isEmpty ? S.required : null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.onSkip == null,
        actions: [if (widget.onSkip != null) TextButton(onPressed: widget.onSkip, child: const Text(S.skipForNow))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + MediaQuery.viewPaddingOf(context).bottom),
          children: [
            Text(
              _register ? S.registerTitle : S.signInTitle,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              widget.forCheckout ? S.checkoutAuthBody : S.authBody,
              style: TextStyle(fontSize: 16, height: 1.4, color: context.mutedText),
            ),
            const SizedBox(height: 24),
            if (_register) ...[
              TextFormField(
                decoration: deco(S.firstName),
                textCapitalization: TextCapitalization.words,
                validator: required,
                onSaved: (v) => _profile.firstName = v!.trim(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                decoration: deco(S.lastName),
                textCapitalization: TextCapitalization.words,
                validator: required,
                onSaved: (v) => _profile.lastName = v!.trim(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                decoration: deco(S.phone, hint: '05xx xxx xx xx'),
                keyboardType: TextInputType.phone,
                validator: required,
                onSaved: (v) => _profile.phone = v!.trim(),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _email,
              decoration: deco(S.email),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              decoration: deco(S.password, hint: _register ? S.passwordHint : null),
              obscureText: true,
              validator: required,
            ),
            if (_register)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _kvkk,
                onChanged: (v) => setState(() => _kvkk = v ?? false),
                title: Text(S.kvkkAccept, style: TextStyle(fontSize: 14, color: context.mutedText)),
                secondary: IconButton(icon: const Icon(Icons.info_outline), onPressed: () => showKvkk(context)),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _forgot, child: const Text(S.forgotPassword)),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.failure)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_register ? S.register : S.signIn, style: const TextStyle(fontSize: 17)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _register = !_register;
                _error = null;
              }),
              child: Text(_register ? S.haveAccount : S.noAccount),
            ),
          ],
        ),
      ),
    );
  }
}

void showKvkk(BuildContext context) => showDialog<void>(
  context: context,
  builder: (c) => AlertDialog(
    title: const Text(S.kvkkTitle),
    content: const SingleChildScrollView(child: Text(S.kvkkText)),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text(S.ok))],
  ),
);

/// Profil bilgileri, e-posta doğrulama, çıkış ve hesap silme.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final UserProfile _p = UserProfile.fromJson(
    (context.read<AuthService>().profile ?? UserProfile(email: context.read<AuthService>().email ?? '')).toJson(),
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthService>().saveProfile(_p);
      messenger.showSnackBar(const SnackBar(content: Text(S.saved)));
    } on AuthError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete() async {
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(S.deleteAccount),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(S.deleteAccountBody),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: S.password),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(S.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.failure),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthService>().deleteAccount(password.text);
      nav.pop();
    } on AuthError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    InputDecoration deco(String label) => InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
    String? required(String? v) => v == null || v.trim().isEmpty ? S.required : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.profile),
        actions: [TextButton(onPressed: _save, child: const Text(S.save))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(auth.email ?? '', style: TextStyle(fontSize: 16, color: context.mutedText)),
            if (!auth.emailVerified) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(S.emailNotVerified),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await auth.resendVerification();
                            messenger.showSnackBar(const SnackBar(content: Text(S.verificationSent)));
                          },
                          child: const Text(S.resendVerification),
                        ),
                        TextButton(onPressed: auth.refresh, child: const Text(S.iVerified)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              initialValue: _p.firstName,
              decoration: deco(S.firstName),
              validator: required,
              onSaved: (v) => _p.firstName = v!.trim(),
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: _p.lastName,
              decoration: deco(S.lastName),
              validator: required,
              onSaved: (v) => _p.lastName = v!.trim(),
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: _p.phone,
              decoration: deco(S.phone),
              keyboardType: TextInputType.phone,
              validator: required,
              onSaved: (v) => _p.phone = v!.trim(),
            ),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                await auth.signOut();
                nav.pop();
              },
              child: const Text(S.signOut),
            ),
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: AppColors.failure),
              child: const Text(S.deleteAccount),
            ),
          ],
        ),
      ),
    );
  }
}

/// İlk açılışta: oturum yoksa ve atlanmadıysa giriş / kayıt ekranı, sonra [child].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final app = context.watch<AppViewModel>();
    if (!auth.available || auth.signedIn || app.authSkipped) return child;
    if (!auth.ready || app.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return AuthScreen(onSkip: app.skipAuth);
  }
}
