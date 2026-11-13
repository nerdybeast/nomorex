import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// "NoMoreX" in the display style: the product's name on the signed-out
/// screens, exposed to assistive tech as the page heading.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.textAlign = TextAlign.start});

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        'NoMoreX',
        textAlign: textAlign,
        style: Theme.of(context).textTheme.displayLarge?.copyWith(color: NomorexTokens.of(context).palette.fg1),
      ),
    );
  }
}
