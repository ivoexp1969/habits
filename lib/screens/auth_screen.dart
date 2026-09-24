import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';

/// Sign-in / registration screen for the OPTIONAL account. On success it pops
/// with `true` and kicks off a cloud sync. The app is fully usable without ever
/// opening this screen. All strings go through l10n (BG/EN/NL).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  bool _pendingVerification = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<AuthResult> Function() action) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      await CloudSyncService.instance.sync();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else if (res.needsVerification) {
      setState(() {
        _pendingVerification = true;
        _error = res.error == null ? null : authErrorMessage(l10n, res.error!);
      });
    } else {
      setState(() =>
          _error = res.error == null ? null : authErrorMessage(l10n, res.error!));
    }
  }

  void _submitEmail() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    _run(() => _register
        ? AuthService.instance.registerWithEmail(email, pass)
        : AuthService.instance.loginWithEmail(email, pass));
  }

  Future<void> _forgot() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = l10n.authForgotNeedEmail);
      return;
    }
    setState(() => _busy = true);
    final res = await AuthService.instance.resetPassword(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = res.ok ? null : authErrorMessage(l10n, res.error ?? AuthError.generic);
    });
    if (res.ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.authResetSent)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_register ? l10n.authRegisterTitle : l10n.authLoginTitle),
      ),
      body: SafeArea(
        child: _pendingVerification
            ? _verifyView(l10n, scheme)
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _register ? l10n.authRegisterBlurb : l10n.authLoginBlurb,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: l10n.authEmail,
                          prefixIcon: const Icon(Icons.mail_outline),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty || !t.contains('@') || !t.contains('.')) {
                            return l10n.authEmailInvalid;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: l10n.authPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          if ((v ?? '').length < 6) return l10n.authPasswordMin;
                          return null;
                        },
                      ),
                      if (!_register)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy ? null : _forgot,
                            child: Text(l10n.authForgot),
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: scheme.error)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _submitEmail,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(_register
                                      ? l10n.authCreateAccount
                                      : l10n.authLoginAction)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _register = !_register;
                                  _error = null;
                                }),
                        child: Text(_register
                            ? l10n.authHaveAccount
                            : l10n.authNoAccount),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(l10n.authOr,
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                        ),
                        const Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => AuthService.instance.signInWithGoogle()),
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(l10n.authContinueGoogle)),
                      ),
                      if (AuthService.instance.appleAvailable) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => AuthService.instance.signInWithApple()),
                          icon: const Icon(Icons.apple),
                          label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(l10n.authContinueApple)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _verifyView(AppLocalizations l10n, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mark_email_unread_outlined, size: 64, color: scheme.primary),
          const SizedBox(height: 16),
          Text(l10n.authVerifyTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            l10n.authVerifyBody,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final verified =
                        await AuthService.instance.reloadAndCheckVerified();
                    if (!mounted) return;
                    setState(() => _busy = false);
                    if (verified) {
                      await CloudSyncService.instance.sync();
                      if (!mounted) return;
                      Navigator.of(context).pop(true);
                    } else {
                      setState(() => _error = l10n.authNotVerifiedYet);
                    }
                  },
            child: Text(l10n.authVerifiedBtn),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed:
                _busy ? null : () => AuthService.instance.resendVerification(),
            child: Text(l10n.authResend),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error)),
          ],
        ],
      ),
    );
  }
}
