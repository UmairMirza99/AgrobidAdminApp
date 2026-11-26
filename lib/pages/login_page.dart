import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final Session session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.login(_email.text, _password.text);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(children: [
        if (wide) const Expanded(flex: 5, child: _BrandPanel()),
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: _buildForm(context, wide)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildForm(BuildContext context, bool wide) {
    final theme = Theme.of(context);
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!wide) ...[
            const Align(alignment: Alignment.centerLeft, child: _Logo(size: 44)),
            const SizedBox(height: 24),
          ],
          Text('AgroBid Admin', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          Text('Sign in to your account', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          const SizedBox(height: 6),
          Text('Use your administrator email and password.', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
          const SizedBox(height: 32),
          const _FieldLabel('Email'),
          TextFormField(
            controller: _email,
            autofillHints: const [AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'admin@example.com', prefixIcon: Icon(Icons.mail_outline, size: 20)),
            validator: (v) => (v ?? '').contains('@') ? null : 'Enter your admin email',
          ),
          const SizedBox(height: 18),
          const _FieldLabel('Password'),
          TextFormField(
            controller: _password,
            obscureText: _hidden,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'At least 12 characters',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            ),
            validator: (v) => (v ?? '').length >= 12 ? null : 'Admin passwords have at least 12 characters',
          ),
          if (_error != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Sign in'),
            ),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.dns_outlined, size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Expanded(child: Text(apiBaseUrl, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
          ]),
        ]),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)));
}

class _Logo extends StatelessWidget {
  const _Logo({this.size = 40, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: 0.12) : AppColors.primary,
          borderRadius: BorderRadius.circular(size * 0.26),
          border: onDark ? Border.all(color: Colors.white.withValues(alpha: 0.2)) : null,
        ),
        child: Icon(Icons.agriculture, color: Colors.white, size: size * 0.56),
      );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF14492A), AppColors.sidebar]),
      ),
      child: Stack(children: [
        // Soft decorative circles.
        Positioned(right: -120, top: -120, child: _circle(360, 0.05)),
        Positioned(left: -80, bottom: -140, child: _circle(320, 0.04)),
        Padding(
          padding: const EdgeInsets.all(56),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              _Logo(size: 40, onDark: true),
              SizedBox(width: 12),
              Text('AgroBid', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            ]),
            const Spacer(),
            const Text(
              'Fair grain trading,\nverified and transparent.',
              style: TextStyle(color: Colors.white, fontSize: 36, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.8),
            ),
            const SizedBox(height: 16),
            const Text(
              'Review identities, moderate listings and bids, and keep the official price benchmark up to date.',
              style: TextStyle(color: AppColors.sidebarText, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 40),
            for (final (icon, text) in const [
              (Icons.verified_user_outlined, 'Identity verification for farmers and buyers'),
              (Icons.gavel_outlined, 'Listing and bid moderation'),
              (Icons.insights_outlined, 'Official price benchmark management'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14))),
                ]),
              ),
            const Spacer(),
            const Text('© AgroBid · Administrator access only', style: TextStyle(color: Color(0xFF6F8A79), fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  static Widget _circle(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
      );
}
