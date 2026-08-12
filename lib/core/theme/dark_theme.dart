import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from the "Sleek Orange" design system that have no stock
/// [ThemeData]/[ColorScheme]/[TextTheme] slot.
class NomorexDarkTokens extends ThemeExtension<NomorexDarkTokens> {
  const NomorexDarkTokens({
    required this.overline,
    required this.stepperValue,
    required this.stepperValueDecoration,
    required this.stepperDecrementStyle,
    required this.stepperIncrementStyle,
    required this.secondaryButtonStyle,
    required this.dangerButtonStyle,
  });

  final TextStyle overline;
  final TextStyle stepperValue;

  /// Shared [NumberStepperField] chrome — no visible box around the value,
  /// pill decrement/increment buttons — so every stepper in the app (PR
  /// weight/reps, set-editor dialogs) looks the same without each call site
  /// re-deriving these from [ColorScheme].
  final InputDecoration stepperValueDecoration;
  final ButtonStyle stepperDecrementStyle;
  final ButtonStyle stepperIncrementStyle;

  /// Same shape/size as the themed [FilledButton] (full-width, 56px,
  /// 4px-radius corners), but blue instead of the orange primary — for a
  /// secondary/alternate action sitting next to a primary [FilledButton]
  /// (e.g. "Pause" beside "Finish"), where an action still needs equal
  /// visual weight rather than the deliberately lighter [OutlinedButton].
  final ButtonStyle secondaryButtonStyle;

  /// Same shape/size again, but red — for a destructive/irreversible action
  /// (e.g. "Discard"), distinct from [ColorScheme.error] which this theme
  /// uses for form-validation messaging, not buttons.
  final ButtonStyle dangerButtonStyle;

  @override
  NomorexDarkTokens copyWith({
    TextStyle? overline,
    TextStyle? stepperValue,
    InputDecoration? stepperValueDecoration,
    ButtonStyle? stepperDecrementStyle,
    ButtonStyle? stepperIncrementStyle,
    ButtonStyle? secondaryButtonStyle,
    ButtonStyle? dangerButtonStyle,
  }) {
    return NomorexDarkTokens(
      overline: overline ?? this.overline,
      stepperValue: stepperValue ?? this.stepperValue,
      stepperValueDecoration: stepperValueDecoration ?? this.stepperValueDecoration,
      stepperDecrementStyle: stepperDecrementStyle ?? this.stepperDecrementStyle,
      stepperIncrementStyle: stepperIncrementStyle ?? this.stepperIncrementStyle,
      secondaryButtonStyle: secondaryButtonStyle ?? this.secondaryButtonStyle,
      dangerButtonStyle: dangerButtonStyle ?? this.dangerButtonStyle,
    );
  }

  @override
  NomorexDarkTokens lerp(ThemeExtension<NomorexDarkTokens>? other, double t) {
    if (other is! NomorexDarkTokens) return this;
    return t < 0.5 ? this : other;
  }
}

/// The app's theme ("Sleek Orange") — wired globally via `MaterialApp.theme`
/// in `app.dart`.
class AppDarkTheme {
  static const _bg0 = Color(0xFF0F0F10);
  static const _bg1 = Color(0xFF1A1A1F);
  static const _bg2 = Color(0xFF242429);
  static const _bg3 = Color(0xFF2E2E35);
  static const _borderSubtle = Color(0xFF2E2E35);
  static const _borderDefault = Color(0xFF3A3A42);
  static const _fg1 = Color(0xFFF0F0F2);
  static const _fg3 = Color(0xFF9898A6);
  static const _primary = Color(0xFFFC5201);
  // Not ColorScheme.secondary (that's deliberately pinned to _primary above
  // so untouched stock M3 widgets don't fall back to the Material baseline
  // purple/teal) — this is specifically the color for a secondary/alternate
  // *button*, e.g. "Pause" next to a primary "Finish" FilledButton.
  static const _secondaryButton = Color(0xFF2563EB);
  // A distinct red for destructive/"dangerous" action buttons (e.g.
  // "Discard") — separate from _error/_errorText below, which are for
  // form-validation messaging, not buttons.
  static const _danger = Color(0xFFB91C1C);
  static const _error = Color(0xFFE74C3C);
  static const _errorText = Color(0xFFFF6F61);
  // "Orange background tint" from the design system's card active/selected
  // spec (rgba(252,82,1,0.08)) — used wherever a *Container role needs to
  // read as a faint primary wash rather than a distinct color.
  static final _primarySubtle = _primary.withValues(alpha: 0.12);

  static ThemeData sleekOrange() {
    final colorScheme = ColorScheme.dark(
      primary: _primary,
      onPrimary: Colors.white,
      // The design system has one accent, not a distinct secondary hue —
      // pin secondary (and tertiary, and every *Container role) to primary
      // so stock M3 widgets we haven't explicitly themed (NavigationRail
      // indicator, SegmentedButton, SnackBar, etc.) don't fall back to the
      // Material baseline purple/teal dark palette.
      secondary: _primary,
      onSecondary: Colors.white,
      secondaryContainer: _primarySubtle,
      onSecondaryContainer: _fg1,
      tertiary: _primary,
      onTertiary: Colors.white,
      tertiaryContainer: _primarySubtle,
      onTertiaryContainer: _fg1,
      error: _error,
      onError: Colors.white,
      surface: _bg2,
      onSurface: _fg1,
      onSurfaceVariant: _fg3,
      surfaceContainerLowest: _bg0,
      surfaceContainerLow: _bg1,
      surfaceContainer: _bg2,
      surfaceContainerHigh: _bg3,
      primaryContainer: _primarySubtle,
      onPrimaryContainer: _fg1,
      inverseSurface: _fg1,
      onInverseSurface: _bg0,
      inversePrimary: _primary,
      outline: _borderDefault,
      outlineVariant: _borderSubtle,
      surfaceTint: Colors.transparent,
    );

    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme)
        .apply(bodyColor: _fg1, displayColor: _fg1);
    // Design system: Barlow for display/heading roles, Inter for body/UI —
    // only headline-and-up sizes get the swap so buttons/labels/inputs stay
    // on Inter.
    final textTheme = baseTextTheme.copyWith(
      displayLarge: GoogleFonts.barlow(textStyle: baseTextTheme.displayLarge, fontWeight: FontWeight.w700),
      displayMedium: GoogleFonts.barlow(textStyle: baseTextTheme.displayMedium, fontWeight: FontWeight.w700),
      displaySmall: GoogleFonts.barlow(textStyle: baseTextTheme.displaySmall, fontWeight: FontWeight.w700),
      headlineLarge: GoogleFonts.barlow(textStyle: baseTextTheme.headlineLarge, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.barlow(textStyle: baseTextTheme.headlineMedium, fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.barlow(textStyle: baseTextTheme.headlineSmall, fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.barlow(textStyle: baseTextTheme.titleLarge, fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _bg0,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _bg1,
        elevation: 0,
        centerTitle: false,
        shape: const Border(bottom: BorderSide(color: _borderSubtle)),
        iconTheme: const IconThemeData(color: _fg1),
        titleTextStyle: GoogleFonts.barlow(fontSize: 18, fontWeight: FontWeight.w600, color: _fg1),
      ),
      cardTheme: CardThemeData(
        color: _bg1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _borderSubtle),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _bg1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: _borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: _borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: _primary),
        ),
        hintStyle: const TextStyle(color: _fg3),
        labelStyle: const TextStyle(color: _fg3),
        errorStyle: const TextStyle(color: _errorText),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : _fg3,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? _primary : _bg3,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        // Flat, no-shadow design — the stock hover/focus overlay is a
        // translucent orange halo that visually merges into the white thumb.
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _bg1,
        indicatorColor: _primarySubtle,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        selectedIconTheme: const IconThemeData(color: _primary),
        unselectedIconTheme: const IconThemeData(color: _fg3),
        selectedLabelTextStyle: const TextStyle(color: _fg1, fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelTextStyle: const TextStyle(color: _fg3, fontSize: 13),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _bg2,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          side: const BorderSide(color: _borderDefault),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _fg3,
        textColor: _fg1,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: _bg1,
          foregroundColor: _fg3,
          selectedBackgroundColor: _primary,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: _borderDefault),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _bg3,
        contentTextStyle: GoogleFonts.inter(color: _fg1),
        actionTextColor: _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(color: _borderSubtle, space: 1, thickness: 1),
      extensions: [
        NomorexDarkTokens(
          overline: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.32, // 0.12em @ 11px
            color: _fg3,
          ),
          stepperValue: GoogleFonts.barlowCondensed(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _fg1,
          ),
          stepperValueDecoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          stepperDecrementStyle: IconButton.styleFrom(
            backgroundColor: _bg3,
            foregroundColor: _fg1,
            shape: const CircleBorder(),
          ),
          stepperIncrementStyle: IconButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
          ),
          secondaryButtonStyle: FilledButton.styleFrom(
            backgroundColor: _secondaryButton,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          dangerButtonStyle: FilledButton.styleFrom(
            backgroundColor: _danger,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
