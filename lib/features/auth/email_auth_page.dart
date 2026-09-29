import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../core/providers.dart';
import '../../core/widgets.dart';

enum EmailAuthMode {
  /// Misafir hesabı e-postaya bağla (veriler korunur).
  link,

  /// Başka cihazda oluşturulmuş hesaba giriş.
  signIn,
}

/// Şifresiz e-posta doğrulaması: 6 haneli tek kullanımlık kod.
class EmailAuthPage extends ConsumerStatefulWidget {
  const EmailAuthPage({super.key, required this.mode});
  final EmailAuthMode mode;

  @override
  ConsumerState<EmailAuthPage> createState() => _EmailAuthPageState();
}

class _EmailAuthPageState extends ConsumerState<EmailAuthPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final account = ref.read(accountRepositoryProvider)!;
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      showSnack(context, l.invalidEmail);
      return;
    }
    setState(() => _busy = true);
    try {
      if (!_codeSent) {
        widget.mode == EmailAuthMode.link
            ? await account.startLinkEmail(email)
            : await account.startEmailSignIn(email);
        setState(() => _codeSent = true);
      } else {
        widget.mode == EmailAuthMode.link
            ? await account.confirmLinkEmail(email, _code.text.trim())
            : await account.confirmEmailSignIn(email, _code.text.trim());
        ref
          ..invalidate(portfoliosProvider)
          ..invalidate(manualPricesProvider)
          ..invalidate(alertsProvider);
        if (mounted) {
          showSnack(context, l.emailVerified);
          context.go('/settings');
        }
      }
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (_) {
      if (mounted) showSnack(context, l.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = widget.mode == EmailAuthMode.link ? l.linkEmail : l.signInExisting;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (widget.mode == EmailAuthMode.signIn)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(l.signInWarning, style: Theme.of(context).textTheme.bodySmall),
          ),
        TextField(
          controller: _email,
          enabled: !_codeSent,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(labelText: l.email),
        ),
        if (_codeSent) ...[
          const SizedBox(height: 8),
          Text(l.codeSent(_email.text.trim())),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: InputDecoration(labelText: l.code),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_codeSent ? l.verify : l.sendCode),
        ),
      ]),
    );
  }
}
