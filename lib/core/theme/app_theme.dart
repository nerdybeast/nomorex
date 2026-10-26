import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The raw color values of the Sleek Orange design system (v3), one set per
/// theme. Token names match the design system one to one; nothing outside
/// this file should hardcode a [Color].
class NomorexPalette {
  const NomorexPalette({
    required this.brightness,
    required this.bg0,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderControl,
    required this.fg1,
    required this.fg2,
    required this.fg3,
    required this.primary,
    required this.primaryHover,
    required this.primaryBorder,
    required this.onPrimary,
    required this.primaryText,
    required this.primarySubtle,
    required this.info,
    required this.danger,
    required this.dangerHover,
    required this.onDanger,
    required this.dangerText,
    required this.dangerSubtle,
    required this.overlayShadow,
  });

  final Brightness brightness;

  /// Page, app bar, bottom nav, and recessed strips (list headers, dialog
  /// footers).
  final Color bg0;

  /// Cards, list containers, the navigation rail.
  final Color bg1;

  /// Overlays, text-field fills, secondary buttons, icon tiles.
  final Color bg2;

  /// Raised fills: hover/pressed rows, selected nav item, snackbars, the
  /// switch's off track.
  final Color bg3;

  final Color borderSubtle;
  final Color borderDefault;

  /// Field outlines and the stepper's − button; 3:1 or better on bg-0..bg-2.
  final Color borderControl;

  final Color fg1;
  final Color fg2;
  final Color fg3;

  final Color primary;
  final Color primaryHover;
  final Color primaryBorder;
  final Color onPrimary;

  /// Orange as text: links, snackbar actions, the selected nav icon.
  final Color primaryText;

  /// A faint orange wash behind primary-text (selected unit, today's row).
  final Color primarySubtle;

  /// Blue as text only: a weight resolved from the viewer's own or
  /// estimated 1RM.
  final Color info;

  final Color danger;
  final Color dangerHover;
  final Color onDanger;

  /// Validation messages, invalid outlines, destructive menu items.
  final Color dangerText;
  final Color dangerSubtle;

  /// Shadow color for overlays (dialogs, sheets, menus, snackbars). In-flow
  /// surfaces never cast a shadow.
  final Color overlayShadow;

  static const dark = NomorexPalette(
    brightness: Brightness.dark,
    bg0: Color(0xFF121212),
    bg1: Color(0xFF171717),
    bg2: Color(0xFF1C1C1C),
    bg3: Color(0xFF262626),
    borderSubtle: Color(0xFF262626),
    borderDefault: Color(0xFF333333),
    borderControl: Color(0xFF6B6B6B),
    fg1: Color(0xFFEDEDED),
    fg2: Color(0xFFA1A1A1),
    fg3: Color(0xFF8F8F8F),
    primary: Color(0xFFC8470F),
    primaryHover: Color(0xFFB8420F),
    primaryBorder: Color(0xFFDD6A35),
    onPrimary: Color(0xFFFFFFFF),
    primaryText: Color(0xFFF5814A),
    primarySubtle: Color(0x29C8470F), // rgba(200, 71, 15, 0.16)
    info: Color(0xFF6AA6F8),
    danger: Color(0xFFC93434),
    dangerHover: Color(0xFFB52E2E),
    onDanger: Color(0xFFFFFFFF),
    dangerText: Color(0xFFFF7B72),
    dangerSubtle: Color(0x1AFF7B72), // rgba(255, 123, 114, 0.10)
    overlayShadow: Color(0x8C000000), // rgba(0, 0, 0, 0.55)
  );

  static const light = NomorexPalette(
    brightness: Brightness.light,
    bg0: Color(0xFFFAFAFA),
    bg1: Color(0xFFFFFFFF),
    bg2: Color(0xFFFFFFFF),
    bg3: Color(0xFFF0F0F0),
    borderSubtle: Color(0xFFEBEBEB),
    borderDefault: Color(0xFFDEDEDE),
    borderControl: Color(0xFF8F8F8F),
    fg1: Color(0xFF171717),
    fg2: Color(0xFF525252),
    fg3: Color(0xFF6B6B6B),
    primary: Color(0xFFC2410C),
    primaryHover: Color(0xFFAD3A0B),
    primaryBorder: Color(0xFF9A3412),
    onPrimary: Color(0xFFFFFFFF),
    primaryText: Color(0xFFC2410C),
    primarySubtle: Color(0x14C2410C), // rgba(194, 65, 12, 0.08)
    info: Color(0xFF1F63D6),
    danger: Color(0xFFC62828),
    dangerHover: Color(0xFFAD2121),
    onDanger: Color(0xFFFFFFFF),
    dangerText: Color(0xFFC62828),
    dangerSubtle: Color(0x0FC62828), // rgba(198, 40, 40, 0.06)
    overlayShadow: Color(0x14000000), // rgba(0, 0, 0, 0.08)
  );
}

/// Spacing, radius and size tokens. Theme-independent.
abstract final class NomorexSizes {
  static const radiusSm = 4.0;
  static const radiusMd = 6.0;
  static const radiusLg = 10.0;
  static const radiusXl = 14.0;

  static const controlHeightSm = 32.0;
  static const controlHeight = 36.0;
  static const controlHeightLg = 44.0;
  static const touchTarget = 48.0;
  static const iconButtonSize = 40.0;
  static const appBarHeight = 52.0;
  static const navBarHeight = 56.0;
  static const fabSize = 52.0;
  static const iconTileSize = 32.0;
  static const stepperFieldWidth = 80.0;
}

/// Design tokens that have no stock [ThemeData]/[ColorScheme]/[TextTheme]
/// slot, for both the dark and light themes. Read with
/// `Theme.of(context).extension<NomorexTokens>()`.
class NomorexTokens extends ThemeExtension<NomorexTokens> {
  const NomorexTokens({
    required this.palette,
    required this.eyebrow,
    required this.weight,
    required this.weightMd,
    required this.weightLg,
    required this.stepperValue,
    required this.stat,
    required this.timer,
    required this.stepperValueDecoration,
    required this.stepperDecrementStyle,
    required this.stepperIncrementStyle,
    required this.secondaryButtonStyle,
    required this.dangerButtonStyle,
  });

  /// Every color token of the active theme.
  final NomorexPalette palette;

  /// Mono 11/500 caps label above or inside a list ("RECENT PRS"), fg-3.
  /// Callers upper-case the text.
  final TextStyle eyebrow;

  /// Mono weights: 14 inline, 16 in a PR row, 20 on their own.
  final TextStyle weight;
  final TextStyle weightMd;
  final TextStyle weightLg;

  /// Inter 24/600 with tabular figures — the number in every
  /// [NumberStepperField].
  final TextStyle stepperValue;

  /// Inter 20/600 tabular — counts and durations in summaries.
  final TextStyle stat;

  /// Inter 40/600 tabular — the running workout clock. Tabular figures keep
  /// a scaled timer from re-fitting every second.
  final TextStyle timer;

  /// Shared [NumberStepperField] chrome so every stepper looks the same.
  final InputDecoration stepperValueDecoration;
  final ButtonStyle stepperDecrementStyle;
  final ButtonStyle stepperIncrementStyle;

  /// The neutral secondary button: bg-2 fill, border-default edge, fg-1
  /// label. Same size as the themed [FilledButton], for an equal-weight
  /// alternate beside a primary ("Pause" beside "Finish", "Cancel").
  final ButtonStyle secondaryButtonStyle;

  /// Same shape again in danger red, for an irreversible action ("Discard").
  final ButtonStyle dangerButtonStyle;

  /// The active theme's tokens. Falls back to a font-agnostic copy of the
  /// stock tokens (matching the ambient brightness) when the theme doesn't
  /// carry the extension — e.g. a bare `MaterialApp` in a widget test.
  static NomorexTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<NomorexTokens>() ??
        (theme.brightness == Brightness.dark ? _fallbackDark : _fallbackLight);
  }

  static final _fallbackDark =
      AppTheme._build(NomorexPalette.dark, googleFonts: false).extension<NomorexTokens>()!;
  static final _fallbackLight =
      AppTheme._build(NomorexPalette.light, googleFonts: false).extension<NomorexTokens>()!;

  Color get info => palette.info;
  Color get fg2 => palette.fg2;
  Color get fg3 => palette.fg3;
  Color get primaryText => palette.primaryText;

  @override
  NomorexTokens copyWith({
    NomorexPalette? palette,
    TextStyle? eyebrow,
    TextStyle? weight,
    TextStyle? weightMd,
    TextStyle? weightLg,
    TextStyle? stepperValue,
    TextStyle? stat,
    TextStyle? timer,
    InputDecoration? stepperValueDecoration,
    ButtonStyle? stepperDecrementStyle,
    ButtonStyle? stepperIncrementStyle,
    ButtonStyle? secondaryButtonStyle,
    ButtonStyle? dangerButtonStyle,
  }) {
    return NomorexTokens(
      palette: palette ?? this.palette,
      eyebrow: eyebrow ?? this.eyebrow,
      weight: weight ?? this.weight,
      weightMd: weightMd ?? this.weightMd,
      weightLg: weightLg ?? this.weightLg,
      stepperValue: stepperValue ?? this.stepperValue,
      stat: stat ?? this.stat,
      timer: timer ?? this.timer,
      stepperValueDecoration: stepperValueDecoration ?? this.stepperValueDecoration,
      stepperDecrementStyle: stepperDecrementStyle ?? this.stepperDecrementStyle,
      stepperIncrementStyle: stepperIncrementStyle ?? this.stepperIncrementStyle,
      secondaryButtonStyle: secondaryButtonStyle ?? this.secondaryButtonStyle,
      dangerButtonStyle: dangerButtonStyle ?? this.dangerButtonStyle,
    );
  }

  @override
  NomorexTokens lerp(ThemeExtension<NomorexTokens>? other, double t) {
    if (other is! NomorexTokens) return this;
    return t < 0.5 ? this : other;
  }
}

/// The app's themes ("Sleek Orange" v3) — wired via `MaterialApp.theme` /
/// `darkTheme` in `app.dart`.
///
/// One accent: `ColorScheme.secondary`, `tertiary` and every `*Container`
/// role are pinned to the orange (or its subtle wash) so stock M3 widgets
/// never fall back to Material's baseline purple/teal. Anything without a
/// stock slot lives on [NomorexTokens].
abstract final class AppTheme {
  static ThemeData dark() => _build(NomorexPalette.dark);
  static ThemeData light() => _build(NomorexPalette.light);

  static const _tabular = [FontFeature.tabularFigures()];

  // Off only for NomorexTokens' fallback, so a widget test without the app
  // theme never triggers a font fetch.
  static bool _googleFonts = true;

  static TextStyle _inter(double size, double lineHeight, FontWeight weight,
      {double? letterSpacing, Color? color}) {
    if (!_googleFonts) {
      return TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        letterSpacing: letterSpacing ?? 0,
        color: color,
      );
    }
    return GoogleFonts.inter(
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: letterSpacing ?? 0,
      color: color,
    );
  }

  static TextStyle _mono(double size, double lineHeight, {double? letterSpacing, Color? color}) {
    if (!_googleFonts) {
      return TextStyle(
        fontFamily: 'monospace',
        fontSize: size,
        height: lineHeight / size,
        fontWeight: FontWeight.w500,
        letterSpacing: letterSpacing ?? 0,
        color: color,
        fontFeatures: _tabular,
      );
    }
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      height: lineHeight / size,
      fontWeight: FontWeight.w500,
      letterSpacing: letterSpacing ?? 0,
      color: color,
      fontFeatures: _tabular,
    );
  }

  static ThemeData _build(NomorexPalette p, {bool googleFonts = true}) {
    final previous = _googleFonts;
    _googleFonts = googleFonts;
    try {
      return _buildTheme(p);
    } finally {
      _googleFonts = previous;
    }
  }

  static ThemeData _buildTheme(NomorexPalette p) {
    final colorScheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primarySubtle,
      onPrimaryContainer: p.fg1,
      secondary: p.primary,
      onSecondary: p.onPrimary,
      secondaryContainer: p.primarySubtle,
      onSecondaryContainer: p.fg1,
      tertiary: p.primary,
      onTertiary: p.onPrimary,
      tertiaryContainer: p.primarySubtle,
      onTertiaryContainer: p.fg1,
      // ColorScheme.error is read almost everywhere as *text* (validation
      // and failure messages), so it carries danger-text; the button fill
      // is NomorexTokens.dangerButtonStyle.
      error: p.dangerText,
      onError: p.onDanger,
      errorContainer: p.dangerSubtle,
      onErrorContainer: p.dangerText,
      surface: p.bg1,
      onSurface: p.fg1,
      onSurfaceVariant: p.fg2,
      surfaceDim: p.bg0,
      surfaceBright: p.bg2,
      surfaceContainerLowest: p.bg0,
      surfaceContainerLow: p.bg1,
      surfaceContainer: p.bg2,
      surfaceContainerHigh: p.bg3,
      surfaceContainerHighest: p.bg3,
      outline: p.borderControl,
      outlineVariant: p.borderSubtle,
      shadow: p.overlayShadow,
      scrim: const Color(0x99000000),
      inverseSurface: p.fg1,
      onInverseSurface: p.bg0,
      inversePrimary: p.primaryText,
      surfaceTint: Colors.transparent,
    );

    // Inter only, at a small, even scale. Material slot → design style:
    // display* → display (32), headlineLarge/Medium → title-1 (24),
    // headlineSmall/titleLarge → title-2 (18), titleMedium → title-3 (15),
    // titleSmall/labelLarge → button (14/500), bodyLarge/Medium → body (14),
    // bodySmall → caption (12), labelMedium → 12/500, labelSmall → nav (11).
    final textTheme = TextTheme(
      displayLarge: _inter(32, 38, FontWeight.w600, letterSpacing: -0.64),
      displayMedium: _inter(32, 38, FontWeight.w600, letterSpacing: -0.64),
      displaySmall: _inter(32, 38, FontWeight.w600, letterSpacing: -0.64),
      headlineLarge: _inter(24, 30, FontWeight.w600, letterSpacing: -0.36),
      headlineMedium: _inter(24, 30, FontWeight.w600, letterSpacing: -0.36),
      headlineSmall: _inter(18, 24, FontWeight.w600, letterSpacing: -0.18),
      titleLarge: _inter(18, 24, FontWeight.w600, letterSpacing: -0.18),
      titleMedium: _inter(15, 22, FontWeight.w600, letterSpacing: -0.07),
      titleSmall: _inter(14, 20, FontWeight.w500),
      bodyLarge: _inter(14, 20, FontWeight.w400),
      bodyMedium: _inter(14, 20, FontWeight.w400),
      bodySmall: _inter(12, 16, FontWeight.w400),
      labelLarge: _inter(14, 20, FontWeight.w500),
      labelMedium: _inter(12, 16, FontWeight.w500),
      labelSmall: _inter(11, 14, FontWeight.w500),
    ).apply(bodyColor: p.fg1, displayColor: p.fg1);

    final buttonText = _inter(14, 20, FontWeight.w500);
    final rMd = BorderRadius.circular(NomorexSizes.radiusMd);
    final rLg = BorderRadius.circular(NomorexSizes.radiusLg);
    final rXl = BorderRadius.circular(NomorexSizes.radiusXl);

    // Full-width by default (Size.fromHeight), as the app's layouts expect;
    // put a button in a Row/Expanded or give it its own minimumSize to size
    // it to its label.
    ButtonStyle filled({
      required Color bg,
      required Color hover,
      required Color fg,
      required Color edge,
    }) {
      return ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(NomorexSizes.controlHeightLg)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: rMd)),
        textStyle: WidgetStatePropertyAll(buttonText),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return p.bg3;
          if (s.contains(WidgetState.pressed) || s.contains(WidgetState.hovered)) return hover;
          return bg;
        }),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? p.fg3 : fg,
        ),
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(color: s.contains(WidgetState.disabled) ? p.borderSubtle : edge),
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      );
    }

    final primaryButton = filled(bg: p.primary, hover: p.primaryHover, fg: p.onPrimary, edge: p.primaryBorder);
    final secondaryButton = filled(bg: p.bg2, hover: p.bg3, fg: p.fg1, edge: p.borderDefault);
    final dangerButton = filled(bg: p.danger, hover: p.dangerHover, fg: p.onDanger, edge: p.danger);

    OutlineInputBorder outline(Color c, [double width = 1]) =>
        OutlineInputBorder(borderRadius: rMd, borderSide: BorderSide(color: c, width: width));

    final overlayShape = RoundedRectangleBorder(
      borderRadius: rLg,
      side: BorderSide(color: p.borderDefault),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.bg0,
      canvasColor: p.bg0,
      dividerColor: p.borderSubtle,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: p.fg2),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg0,
        foregroundColor: p.fg1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: NomorexSizes.appBarHeight,
        shape: Border(bottom: BorderSide(color: p.borderSubtle)),
        iconTheme: IconThemeData(color: p.fg2),
        actionsIconTheme: IconThemeData(color: p.fg2),
        titleTextStyle: _inter(15, 22, FontWeight.w600, letterSpacing: -0.07, color: p.fg1),
      ),
      cardTheme: CardThemeData(
        color: p.bg1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: rLg,
          side: BorderSide(color: p.borderSubtle),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.bg2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: outline(p.borderControl),
        enabledBorder: outline(p.borderControl),
        disabledBorder: outline(p.borderSubtle),
        focusedBorder: outline(p.primary, 1.5),
        errorBorder: outline(p.dangerText),
        focusedErrorBorder: outline(p.dangerText, 1.5),
        hintStyle: _inter(14, 20, FontWeight.w400, color: p.fg3),
        labelStyle: _inter(14, 20, FontWeight.w400, color: p.fg2),
        floatingLabelStyle: _inter(13, 18, FontWeight.w500, color: p.fg1),
        helperStyle: _inter(12, 16, FontWeight.w400, color: p.fg3),
        errorStyle: _inter(12, 16, FontWeight.w400, color: p.dangerText),
        prefixIconColor: p.fg3,
        suffixIconColor: p.fg2,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NomorexSizes.radiusSm)),
        side: WidgetStateBorderSide.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return BorderSide(color: p.primary, width: 1.5);
          if (s.contains(WidgetState.disabled)) return BorderSide(color: p.borderDefault, width: 1.5);
          return BorderSide(color: p.borderControl, width: 1.5);
        }),
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) {
            return s.contains(WidgetState.disabled) ? p.fg3 : p.primary;
          }
          return s.contains(WidgetState.disabled) ? Colors.transparent : p.bg2;
        }),
        checkColor: WidgetStatePropertyAll(p.onPrimary),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.fg3,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.bg3,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primaryBorder : p.borderDefault,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      filledButtonTheme: FilledButtonThemeData(style: primaryButton),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.fg1,
          backgroundColor: p.bg2,
          minimumSize: const Size(64, NomorexSizes.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: BorderSide(color: p.borderDefault),
          shape: RoundedRectangleBorder(borderRadius: rMd),
          textStyle: buttonText,
        ).copyWith(overlayColor: WidgetStatePropertyAll(p.bg3)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.fg1,
          minimumSize: const Size(48, NomorexSizes.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: rMd),
          textStyle: buttonText,
        ).copyWith(overlayColor: WidgetStatePropertyAll(p.bg3)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.fg2,
          shape: RoundedRectangleBorder(borderRadius: rMd),
        ).copyWith(overlayColor: WidgetStatePropertyAll(p.bg3)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: CircleBorder(side: BorderSide(color: p.primaryBorder)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          // Selected takes the same orange wash + orange label as the
          // selected unit in UnitToggle; the check icon follows the label.
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.primarySubtle : p.bg3,
          ),
          foregroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return p.fg3;
            return s.contains(WidgetState.selected) ? p.primaryText : p.fg2;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: p.borderDefault)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: rMd)),
          textStyle: WidgetStatePropertyAll(_inter(13, 18, FontWeight.w500)),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.fg1,
        unselectedLabelColor: p.fg2,
        labelStyle: _inter(14, 20, FontWeight.w500),
        unselectedLabelStyle: _inter(14, 20, FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: p.fg2, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(1)),
        ),
        dividerColor: p.borderSubtle,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.bg2,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: p.overlayShadow,
        shape: overlayShape,
        textStyle: _inter(14, 20, FontWeight.w400, color: p.fg1),
        labelTextStyle: WidgetStatePropertyAll(_inter(14, 20, FontWeight.w400, color: p.fg1)),
        iconColor: p.fg2,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.bg2),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: WidgetStatePropertyAll(p.overlayShadow),
          elevation: const WidgetStatePropertyAll(8),
          shape: WidgetStatePropertyAll(overlayShape),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.bg2),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(overlayShape),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.bg2,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: p.overlayShadow,
        shape: RoundedRectangleBorder(borderRadius: rXl, side: BorderSide(color: p.borderDefault)),
        titleTextStyle: _inter(18, 24, FontWeight.w600, letterSpacing: -0.18, color: p.fg1),
        contentTextStyle: _inter(14, 20, FontWeight.w400, color: p.fg2),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.bg2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: rXl, side: BorderSide(color: p.borderDefault)),
        headerBackgroundColor: p.bg2,
        headerForegroundColor: p.fg1,
        weekdayStyle: _inter(12, 16, FontWeight.w500, color: p.fg2),
        dayStyle: _inter(14, 20, FontWeight.w400),
        dayForegroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return p.onPrimary;
          if (s.contains(WidgetState.disabled)) return p.fg3;
          return p.fg1;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : Colors.transparent,
        ),
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.primaryText,
        ),
        todayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : Colors.transparent,
        ),
        todayBorder: BorderSide(color: p.primary),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.fg1,
        ),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : Colors.transparent,
        ),
        dividerColor: p.borderSubtle,
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: p.fg1),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: p.primaryText),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.bg2,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.bg2,
        elevation: 12,
        shadowColor: p.overlayShadow,
        showDragHandle: true,
        dragHandleColor: p.borderDefault,
        dragHandleSize: const Size(36, 4),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(NomorexSizes.radiusXl)),
          side: BorderSide(color: p.borderDefault),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.bg3,
        contentTextStyle: _inter(13, 18, FontWeight.w400, color: p.fg1),
        actionTextColor: p.primaryText,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: rMd, side: BorderSide(color: p.borderDefault)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        circularTrackColor: Colors.transparent,
        linearTrackColor: p.bg3,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.bg1,
        indicatorColor: p.bg3,
        indicatorShape: RoundedRectangleBorder(borderRadius: rMd),
        selectedIconTheme: IconThemeData(color: p.primaryText, size: 20),
        unselectedIconTheme: IconThemeData(color: p.fg3, size: 20),
        selectedLabelTextStyle: _inter(11, 14, FontWeight.w500, color: p.fg1),
        unselectedLabelTextStyle: _inter(11, 14, FontWeight.w500, color: p.fg3),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.fg2,
        textColor: p.fg1,
        titleTextStyle: _inter(14, 20, FontWeight.w500, color: p.fg1),
        subtitleTextStyle: _inter(13, 18, FontWeight.w400, color: p.fg2),
        shape: RoundedRectangleBorder(borderRadius: rMd),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: p.fg3,
        collapsedIconColor: p.fg3,
        textColor: p.fg1,
        collapsedTextColor: p.fg1,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      dividerTheme: DividerThemeData(color: p.borderSubtle, space: 1, thickness: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: p.fg1, borderRadius: rMd),
        textStyle: _inter(12, 16, FontWeight.w500, color: p.bg0),
      ),
      extensions: [
        NomorexTokens(
          palette: p,
          eyebrow: _mono(11, 16, letterSpacing: 0.66, color: p.fg3),
          weight: _mono(14, 20),
          weightMd: _mono(16, 22, letterSpacing: -0.16),
          weightLg: _mono(20, 26, letterSpacing: -0.2),
          stepperValue: _inter(24, 30, FontWeight.w600, letterSpacing: -0.24, color: p.fg1)
              .copyWith(fontFeatures: _tabular),
          stat: _inter(20, 26, FontWeight.w600, letterSpacing: -0.2, color: p.fg1)
              .copyWith(fontFeatures: _tabular),
          timer: _inter(40, 48, FontWeight.w600, letterSpacing: -0.8, color: p.fg1)
              .copyWith(fontFeatures: _tabular),
          stepperValueDecoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          stepperDecrementStyle: IconButton.styleFrom(
            backgroundColor: p.bg2,
            foregroundColor: p.fg1,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: p.fg3,
            fixedSize: const Size.square(NomorexSizes.iconButtonSize),
            shape: RoundedRectangleBorder(borderRadius: rMd),
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (s) => BorderSide(color: s.contains(WidgetState.disabled) ? p.borderSubtle : p.borderControl),
            ),
          ),
          stepperIncrementStyle: IconButton.styleFrom(
            backgroundColor: p.primary,
            foregroundColor: p.onPrimary,
            disabledBackgroundColor: p.bg3,
            disabledForegroundColor: p.fg3,
            fixedSize: const Size.square(NomorexSizes.iconButtonSize),
            shape: RoundedRectangleBorder(borderRadius: rMd),
            side: BorderSide(color: p.primaryBorder),
          ),
          secondaryButtonStyle: secondaryButton,
          dangerButtonStyle: dangerButton,
        ),
      ],
    );
  }
}
