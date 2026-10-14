import 'package:flutter/material.dart';

import 'nothing_colors.dart';
import 'nothing_typography.dart';

abstract final class NothingTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: NothingColors.ink,
      onPrimary: NothingColors.white,
      primaryContainer: NothingColors.ink,
      onPrimaryContainer: NothingColors.white,
      secondary: NothingColors.red,
      onSecondary: NothingColors.white,
      secondaryContainer: NothingColors.red,
      onSecondaryContainer: NothingColors.white,
      tertiary: NothingColors.inkMuted,
      onTertiary: NothingColors.white,
      error: NothingColors.red,
      onError: NothingColors.white,
      surface: NothingColors.surface,
      onSurface: NothingColors.ink,
      onSurfaceVariant: NothingColors.inkMuted,
      outline: NothingColors.outline,
      outlineVariant: NothingColors.outlineStrong,
      inverseSurface: NothingColors.ink,
      onInverseSurface: NothingColors.white,
      inversePrimary: NothingColors.white,
      shadow: Colors.transparent,
      scrim: Color(0x99000000),
    );

    final roundedRectangle = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(NothingGeometry.radiusMedium),
    );
    final outlinedRectangle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(NothingGeometry.radiusMedium),
      borderSide: const BorderSide(color: NothingColors.outline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: NothingColors.canvas,
      canvasColor: NothingColors.canvas,
      textTheme: NothingTypography.textTheme,
      // Snappier than the platform default, which overshoots the 200–300ms
      // band that reads as responsive without feeling rushed.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      iconTheme: const IconThemeData(color: NothingColors.ink, size: 22),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: NothingColors.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: NothingTypography.titleLarge.copyWith(
          color: NothingColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: NothingColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: roundedRectangle,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: NothingColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NothingGeometry.radiusLarge),
        ),
        titleTextStyle: NothingTypography.titleLarge.copyWith(
          color: NothingColors.ink,
        ),
        contentTextStyle: NothingTypography.bodyMedium.copyWith(
          color: NothingColors.inkMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: NothingColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        labelStyle: NothingTypography.labelMedium.copyWith(
          color: NothingColors.inkMuted,
        ),
        floatingLabelStyle: NothingTypography.labelMedium.copyWith(
          color: NothingColors.ink,
        ),
        hintStyle: NothingTypography.bodyMedium.copyWith(
          color: NothingColors.inkMuted,
        ),
        border: outlinedRectangle,
        enabledBorder: outlinedRectangle,
        focusedBorder: outlinedRectangle.copyWith(
          borderSide: const BorderSide(color: NothingColors.ink, width: 1.5),
        ),
        errorBorder: outlinedRectangle.copyWith(
          borderSide: const BorderSide(color: NothingColors.red),
        ),
        focusedErrorBorder: outlinedRectangle.copyWith(
          borderSide: const BorderSide(color: NothingColors.red, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(0, NothingGeometry.controlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: const WidgetStatePropertyAll(NothingColors.ink),
          foregroundColor: const WidgetStatePropertyAll(NothingColors.white),
          textStyle: const WidgetStatePropertyAll(NothingTypography.labelLarge),
          shape: WidgetStatePropertyAll(roundedRectangle),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(0, NothingGeometry.controlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          foregroundColor: const WidgetStatePropertyAll(NothingColors.ink),
          side: const WidgetStatePropertyAll(
            BorderSide(color: NothingColors.outlineStrong),
          ),
          textStyle: const WidgetStatePropertyAll(NothingTypography.labelLarge),
          shape: WidgetStatePropertyAll(roundedRectangle),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(
              NothingGeometry.minimumTapTarget,
              NothingGeometry.minimumTapTarget,
            ),
          ),
          foregroundColor: const WidgetStatePropertyAll(NothingColors.ink),
          textStyle: const WidgetStatePropertyAll(NothingTypography.labelLarge),
          shape: WidgetStatePropertyAll(roundedRectangle),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: NothingColors.red,
        foregroundColor: NothingColors.white,
        shape: CircleBorder(),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return NothingColors.disabled;
          }
          if (states.contains(WidgetState.selected)) {
            return NothingColors.red;
          }
          return NothingColors.outlineStrong;
        }),
        thumbColor: const WidgetStatePropertyAll(NothingColors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return NothingColors.red;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(NothingColors.white),
        side: const BorderSide(color: NothingColors.outlineStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: NothingColors.surface,
        selectedColor: NothingColors.ink,
        disabledColor: NothingColors.disabled,
        labelStyle: NothingTypography.labelMedium.copyWith(
          color: NothingColors.ink,
        ),
        secondaryLabelStyle: NothingTypography.labelMedium.copyWith(
          color: NothingColors.white,
        ),
        side: const BorderSide(color: NothingColors.outline),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        showCheckmark: false,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: NothingColors.ink,
        textColor: NothingColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        minTileHeight: NothingGeometry.controlHeight,
      ),
      dividerTheme: const DividerThemeData(
        color: NothingColors.outline,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: NothingColors.ink,
        contentTextStyle: NothingTypography.bodyMedium.copyWith(
          color: NothingColors.white,
        ),
        shape: roundedRectangle,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NothingColors.red,
        linearTrackColor: NothingColors.outline,
        circularTrackColor: NothingColors.outline,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: NothingColors.ink,
          borderRadius: BorderRadius.circular(NothingGeometry.radiusSmall),
        ),
        textStyle: NothingTypography.labelMedium.copyWith(
          color: NothingColors.white,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: NothingColors.surface,
        hourMinuteColor: NothingColors.canvas,
        hourMinuteTextColor: NothingColors.ink,
        dayPeriodColor: NothingColors.canvas,
        dayPeriodTextColor: NothingColors.ink,
        dialBackgroundColor: NothingColors.canvas,
        dialHandColor: NothingColors.red,
        dialTextColor: NothingColors.ink,
        entryModeIconColor: NothingColors.ink,
        helpTextStyle: NothingTypography.labelMedium.copyWith(
          color: NothingColors.inkMuted,
        ),
        hourMinuteTextStyle: NothingTypography.headlineLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NothingGeometry.radiusLarge),
        ),
      ),
    );
  }
}
