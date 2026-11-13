import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/wordmark.dart';

/// Shown under "Log in": there's no sign-up, so say how accounts happen.
const kInviteOnlyNote = 'NoMoreX accounts are by invitation only.';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              // The same width as the login form, so the button doesn't run
              // the full width of a desktop window.
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Wordmark(textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Track your strength. Own your PRs.',
                    style: theme.textTheme.titleMedium?.copyWith(color: tokens.palette.fg2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  FilledButton(
                    key: const Key('landing_login_button'),
                    // go, not push: the address bar then shows /login, so a
                    // refresh stays on the login page.
                    onPressed: () => context.go(AppConstants.routeLogin),
                    child: const Text('Log in'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    kInviteOnlyNote,
                    textAlign: TextAlign.center,
                    style: tokens.bodySmall.copyWith(color: tokens.palette.fg3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
