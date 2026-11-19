import 'package:material_ui/material_ui.dart';

const bmsRed = Color(0xFFE7394D);

ThemeData buildTheme(Brightness brightness) {
  // Calm tonal palette for surfaces, with the vivid brand red for primary.
  final vivid = ColorScheme.fromSeed(
    seedColor: bmsRed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final scheme = ColorScheme.fromSeed(seedColor: bmsRed, brightness: brightness)
      .copyWith(
    primary: vivid.primary,
    onPrimary: vivid.onPrimary,
    primaryContainer: vivid.primaryContainer,
    onPrimaryContainer: vivid.onPrimaryContainer,
  );
  final base = ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    useMaterial3: true,
  );
  final radius = BorderRadius.circular(20);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: base.textTheme.labelLarge
            ?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Status colours that read well in light and dark mode.
class StatusColors {
  StatusColors(this.context);
  final BuildContext context;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get success => _dark ? const Color(0xFF6DD58C) : const Color(0xFF146C2E);
  Color get successContainer =>
      _dark ? const Color(0xFF0F5223) : const Color(0xFFC4EED0);
  Color get warning => _dark ? const Color(0xFFFFB95C) : const Color(0xFF8A5100);
  Color get warningContainer =>
      _dark ? const Color(0xFF5C3A00) : const Color(0xFFFFDDB8);
}

/// Pill-shaped filled search field decoration.
InputDecoration searchDecoration(BuildContext context, String hint) {
  final scheme = Theme.of(context).colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(28),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hint,
    prefixIcon: const Icon(Icons.search),
    filled: true,
    fillColor: scheme.surfaceContainerHigh,
    border: border,
    enabledBorder: border,
    focusedBorder: border,
  );
}
