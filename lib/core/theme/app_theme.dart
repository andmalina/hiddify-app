import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

class AppTheme {
  AppTheme(this.mode, this.fontFamily);
  final AppThemeMode mode;
  final String fontFamily;

  // Твоя киберпанк-палитра Malinarium
  static const Color neonFuchsia = Color(0xFFFF00FF); // Яркая кибер-малина
  static const Color neonCyan = Color(0xFF00FFFF);    // Неоновый циан для акцентов
  static const Color deepBlack = Color(0xFF09090B);   // Глубокий темный фон (почти космос)
  static const Color panelGray = Color(0xFF161618);   // Цвет панелей и карточек

  ThemeData lightTheme(ColorScheme? lightColorScheme) {
    // Оставляем светлую тему на случай, если кто-то переключит,
    // но делаем её в фирменных малиновых тонах.
    final ColorScheme scheme = lightColorScheme ?? ColorScheme.fromSeed(seedColor: neonFuchsia);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
  }

  ThemeData darkTheme(ColorScheme? darkColorScheme) {
    // Генерируем настоящую киберпанк-палитру
    final ColorScheme scheme = darkColorScheme ?? ColorScheme.fromSeed(
      seedColor: neonFuchsia,
      brightness: Brightness.dark,
      primary: neonFuchsia,
      secondary: neonCyan,
      surface: panelGray,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Если включен режим "True Black", фон чисто черный, иначе — глубокий техно-черный
      scaffoldBackgroundColor: mode.trueBlack ? Colors.black : deepBlack,
      fontFamily: fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      // Стилизация карточек под футуристичные панели с тонкой неоновой рамкой
      cardTheme: CardTheme(
        color: panelGray,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: neonFuchsia, width: 0.3), // Легкое свечение
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
  }

  CupertinoThemeData cupertinoThemeData(bool sysDark, ColorScheme? lightColorScheme, ColorScheme? darkColorScheme) {
    final bool isDark = switch (mode) {
      AppThemeMode.system => sysDark,
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
      AppThemeMode.black => true,
    };
    final def = CupertinoThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: neonFuchsia, // Фирменный цвет для iOS-элементов
    );

    final defaultMaterialTheme = isDark ? darkTheme(darkColorScheme) : lightTheme(lightColorScheme);
    return MaterialBasedCupertinoThemeData(
      materialTheme: defaultMaterialTheme.copyWith(
        cupertinoOverrideTheme: def.copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: def.textTheme.textStyle.copyWith(fontFamily: fontFamily),
            actionTextStyle: def.textTheme.actionTextStyle.copyWith(fontFamily: fontFamily),
            navActionTextStyle: def.textTheme.navActionTextStyle.copyWith(fontFamily: fontFamily),
            navTitleTextStyle: def.textTheme.navTitleTextStyle.copyWith(fontFamily: fontFamily),
            navLargeTitleTextStyle: def.textTheme.navLargeTitleTextStyle.copyWith(fontFamily: fontFamily),
            pickerTextStyle: def.textTheme.pickerTextStyle.copyWith(fontFamily: fontFamily),
            dateTimePickerTextStyle: def.textTheme.dateTimePickerTextStyle.copyWith(fontFamily: fontFamily),
            tabLabelTextStyle: def.textTheme.tabLabelTextStyle.copyWith(fontFamily: fontFamily),
          ).copyWith(),
          barBackgroundColor: def.barBackgroundColor,
          scaffoldBackgroundColor: def.scaffoldBackgroundColor,
        ),
      ),
    );
  }
}