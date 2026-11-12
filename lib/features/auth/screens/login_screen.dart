import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/login_error.dart';
import '../widgets/wordmark.dart';

/// Shown under the form: there's no in-app reset, because accounts are by
/// invitation and a reset is done by whoever set the account up.
const kForgotPasswordHelp = 'Forgot your password? Contact the person who invited you.';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // Tells password managers the sign-in worked, so they offer to save.
      TextInput.finishAutofillContext();
      // Router redirect handles navigation on auth state change
    } catch (e) {
      if (mounted) setState(() { _error = loginErrorMessage(e); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  /// A failed attempt's message goes as soon as either field is edited, so
  /// it never sits under a corrected password.
  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        // Opened directly (a bookmark or a refresh) there's nothing to pop
        // back to, so Back goes to the landing page instead.
        leading: context.canPop()
            ? null
            : IconButton(
                key: const Key('login_back_button'),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(AppConstants.routeLanding),
              ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: ConstrainedBox(
              // Centers the form on a tall screen and still scrolls when the
              // keyboard leaves less room than it needs.
              constraints: BoxConstraints(minHeight: (constraints.maxHeight - 40).clamp(0, double.infinity)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Wordmark(),
                          const SizedBox(height: 6),
                          Text(
                            'Log in to keep tracking your PRs.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: palette.fg2),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            key: const Key('login_email_field'),
                            controller: _emailController,
                            decoration: const InputDecoration(labelText: 'Email'),
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email, AutofillHints.username],
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.next,
                            onChanged: _clearError,
                            validator: validateLoginEmail,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('login_password_field'),
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                key: const Key('login_show_password'),
                                tooltip: _showPassword ? 'Hide password' : 'Show password',
                                icon: Icon(
                                  _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: palette.fg2,
                                ),
                                onPressed: () => setState(() => _showPassword = !_showPassword),
                              ),
                            ),
                            obscureText: !_showPassword,
                            autofillHints: const [AutofillHints.password],
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.done,
                            onChanged: _clearError,
                            onFieldSubmitted: (_) => _submit(),
                            validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            _LoginErrorBanner(message: _error!),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            key: const Key('login_submit_button'),
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? Semantics(
                                    label: 'Logging in',
                                    liveRegion: true,
                                    child: const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : const Text('Log in'),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            kForgotPasswordHelp,
                            style: tokens.bodySmall.copyWith(color: palette.fg3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty or not shaped like an address. The server is the real check; this
/// only catches a slip ("a@") before a round trip.
String? validateLoginEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
    return 'Enter an email like name@example.com';
  }
  return null;
}

/// A failed sign-in: a `danger-subtle` band with `danger-text`, above the
/// button, announced as soon as it appears.
class _LoginErrorBanner extends StatelessWidget {
  const _LoginErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('login_error'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: palette.dangerSubtle,
          borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline, size: 18, color: palette.dangerText),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: tokens.bodySmall.copyWith(color: palette.dangerText)),
            ),
          ],
        ),
      ),
    );
  }
}
