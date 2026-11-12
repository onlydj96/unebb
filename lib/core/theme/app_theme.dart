import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  /// The global button theme makes buttons full-width (`minimumSize` width =
  /// infinity), which throws inside a `Row` and stacks dialog actions. Use
  /// this for buttons that sit next to others (dialog actions, inline rows).
  static final ButtonStyle compactButton = ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size(64, 44)),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    ),
  );

  static const ColorScheme _scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.cocoa,
    onPrimary: AppColors.paper,
    primaryContainer: AppColors.surfaceElevated,
    onPrimaryContainer: AppColors.cocoa,
    secondary: AppColors.mint,
    onSecondary: AppColors.cocoa,
    secondaryContainer: AppColors.mintSoft,
    onSecondaryContainer: AppColors.cocoa,
    tertiary: AppColors.crimson,
    onTertiary: AppColors.paper,
    tertiaryContainer: AppColors.crimsonSoft,
    onTertiaryContainer: AppColors.crimson,
    error: AppColors.crimson,
    onError: AppColors.paper,
    errorContainer: AppColors.crimsonSoft,
    onErrorContainer: AppColors.crimson,
    surface: AppColors.paper,
    onSurface: AppColors.cocoa,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLowest: AppColors.paper,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    // Dialogs and sheets read as paper laid over the page.
    surfaceContainerHigh: AppColors.paper,
    surfaceContainerHighest: AppColors.surfaceElevated,
    outline: AppColors.outlineStrong,
    outlineVariant: AppColors.outline,
    inverseSurface: AppColors.cocoa,
    onInverseSurface: AppColors.paper,
    inversePrimary: AppColors.mint,
    shadow: AppColors.cocoa,
    scrim: AppColors.cocoa,
    surfaceTint: Colors.transparent,
  );

  static const EdgeInsets _buttonPadding =
      EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  static const Size _buttonMinSize = Size(double.infinity, 54);

  static InputBorder _fieldBorder([BorderSide side = BorderSide.none]) =>
      UnderlineInputBorder(
        borderRadius: AppRadius.mediumBorder,
        borderSide: side,
      );

  static bool _selected(Set<WidgetState> states) =>
      states.contains(WidgetState.selected);

  static const TextTheme _textTheme = TextTheme(
    displayLarge: AppTypography.displayLarge,
    displayMedium: AppTypography.displayMedium,
    displaySmall: AppTypography.displaySmall,
    headlineLarge: AppTypography.headingLarge,
    headlineMedium: AppTypography.headingMedium,
    headlineSmall: AppTypography.headingSmall,
    titleLarge: AppTypography.headingMedium,
    titleMedium: AppTypography.bodyLarge,
    titleSmall: AppTypography.labelLarge,
    bodyLarge: AppTypography.bodyLarge,
    bodyMedium: AppTypography.bodyMedium,
    bodySmall: AppTypography.bodySmall,
    labelLarge: AppTypography.labelLarge,
    labelMedium: AppTypography.labelMedium,
    labelSmall: AppTypography.eyebrow,
  );

  static ThemeData get light {
    // Merged with the platform typography, so these styles carry the
    // platform font family. Component themes below must use them rather
    // than raw [AppTypography] styles: components such as buttons, app bars
    // and dialogs replace (not merge) the inherited text style.
    final text = ThemeData(useMaterial3: true, textTheme: _textTheme).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.largeBorder),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: text.headlineMedium!,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actionsIconTheme: const IconThemeData(color: AppColors.textPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: AppColors.cocoa,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: _selected(states)
                ? AppColors.textOnDark
                : AppColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium!.copyWith(
            color: _selected(states)
                ? AppColors.textPrimary
                : AppColors.textSecondary,
            fontWeight: _selected(states) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: _fieldBorder(),
        enabledBorder: _fieldBorder(),
        disabledBorder: _fieldBorder(),
        focusedBorder: _fieldBorder(
          const BorderSide(color: AppColors.cocoa, width: 2),
        ),
        errorBorder: _fieldBorder(
          const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: _fieldBorder(
          const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: text.bodyMedium!.copyWith(color: AppColors.textMuted),
        labelStyle: text.bodyMedium!.copyWith(color: AppColors.textSecondary),
        floatingLabelStyle: text.labelMedium!.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        errorStyle: text.bodySmall!.copyWith(color: AppColors.error),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cocoa,
          foregroundColor: AppColors.paper,
          disabledBackgroundColor: AppColors.surfaceElevated,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: text.labelLarge!,
          padding: _buttonPadding,
          minimumSize: _buttonMinSize,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cocoa,
          foregroundColor: AppColors.paper,
          disabledBackgroundColor: AppColors.surfaceElevated,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const StadiumBorder(),
          textStyle: text.labelLarge!,
          padding: _buttonPadding,
          minimumSize: _buttonMinSize,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cocoa,
          disabledForegroundColor: AppColors.textMuted,
          side: const BorderSide(color: AppColors.outlineStrong, width: 1.2),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge!,
          padding: _buttonPadding,
          minimumSize: _buttonMinSize,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.cocoa,
          shape: const StadiumBorder(),
          textStyle: text.labelLarge!.copyWith(fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.cocoa),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.cocoa,
        foregroundColor: AppColors.paper,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 1,
        shape: const StadiumBorder(),
        extendedTextStyle: text.labelLarge,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith(
          (states) =>
              _selected(states) ? AppColors.cocoa : AppColors.surfaceElevated,
        ),
        labelStyle: text.bodySmall!.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => _selected(states)
                ? AppColors.textOnDark
                : AppColors.textPrimary,
          ),
          fontWeight: FontWeight.w500,
        ),
        checkmarkColor: AppColors.paper,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xLargeBorder),
        titleTextStyle: text.headlineMedium!,
        contentTextStyle:
            text.bodyMedium!.copyWith(color: AppColors.textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.paper,
        showDragHandle: true,
        dragHandleColor: AppColors.outlineStrong,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xLarge)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cocoa,
        contentTextStyle:
            text.bodyMedium!.copyWith(color: AppColors.textOnDark),
        actionTextColor: AppColors.mint,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mediumBorder),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.cocoa,
        linearTrackColor: AppColors.surfaceElevated,
        circularTrackColor: Colors.transparent,
        refreshBackgroundColor: AppColors.paper,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.cocoa,
        inactiveTrackColor: AppColors.surfaceElevated,
        thumbColor: AppColors.cocoa,
        overlayColor: AppColors.cocoa.withValues(alpha: 0.10),
        valueIndicatorColor: AppColors.cocoa,
        valueIndicatorTextStyle:
            text.labelMedium!.copyWith(color: AppColors.textOnDark),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
        trackHeight: 6,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              _selected(states) ? AppColors.cocoa : AppColors.outlineStrong,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.paper),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              _selected(states) ? AppColors.mintDeep : AppColors.outlineStrong,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.largeBorder),
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        titleTextStyle: text.bodyLarge!,
        subtitleTextStyle:
            text.bodySmall!.copyWith(color: AppColors.textSecondary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.cocoa.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mediumBorder,
          side: const BorderSide(color: AppColors.outline),
        ),
        textStyle: text.bodyMedium!,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.cocoa,
          borderRadius: AppRadius.smallBorder,
        ),
        textStyle: text.bodySmall!.copyWith(color: AppColors.textOnDark),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.cocoa,
        selectionColor: AppColors.mint.withValues(alpha: 0.4),
        selectionHandleColor: AppColors.cocoa,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 0,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      textTheme: _textTheme,
    );
  }
}
