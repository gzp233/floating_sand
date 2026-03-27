import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/shell_page.dart';

/// 应用根组件，统一主题与导航结构。
class PersonalRecordApp extends StatefulWidget {
  const PersonalRecordApp({super.key});

  @override
  State<PersonalRecordApp> createState() => _PersonalRecordAppState();
}

class _PersonalRecordAppState extends State<PersonalRecordApp> {
  static const String _themeModeKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    final storedValue = preferences.getString(_themeModeKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = _themeModeFromStorage(storedValue);
    });
  }

  Future<void> _updateThemeMode(ThemeMode value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, _themeModeToStorage(value));
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.notoSansScTextTheme();

    return MaterialApp(
      title: '个人信息记录',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light, baseTextTheme),
      darkTheme: _buildTheme(Brightness.dark, baseTextTheme),
      themeMode: _themeMode,
      home: AppShellPage(
        themeMode: _themeMode,
        onThemeModeChanged: _updateThemeMode,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness, TextTheme baseTextTheme) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: brightness,
    );

    final scaffoldColor = isDark
        ? const Color(0xFF141917)
        : const Color(0xFFF3F1EB);
    final canvasColor = isDark
        ? const Color(0xFF1A211E)
        : const Color(0xFFF3F1EB);
    final fillColor = isDark
        ? const Color(0xFF202824)
        : const Color(0xFFFAF8F3);
    final borderColor = isDark
        ? const Color(0xFF31403A)
        : const Color(0xFFD7D1C5);
    final actionColor = isDark
        ? const Color(0xFFE6EFEA)
        : const Color(0xFF16302B);
    final navigationBackground = isDark
      ? const Color(0xFF161D1A)
      : const Color(0xFFFBF8F2);
    final mutedForeground = isDark
      ? const Color(0xFFB7C5BF)
      : const Color(0xFF51605B);

    return ThemeData(
      colorScheme: colorScheme,
      textTheme: baseTextTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      scaffoldBackgroundColor: scaffoldColor,
      canvasColor: canvasColor,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1C2421) : Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fillColor,
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFF9EB0A7) : const Color(0xFF5B6964),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF1C2421) : Colors.white,
      ),
      dividerColor: isDark ? const Color(0xFF31403A) : const Color(0xFFD9D3C8),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navigationBackground,
        indicatorColor: Colors.transparent,
        height: 58,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) {
            final isSelected = states.contains(WidgetState.selected);
            return baseTextTheme.labelMedium?.copyWith(
              color: isSelected ? colorScheme.onSurface : mutedForeground,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            );
          },
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (Set<WidgetState> states) {
            return IconThemeData(
              color: Colors.transparent,
              size: 0,
            );
          },
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: actionColor,
          foregroundColor: isDark ? const Color(0xFF10201B) : Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: actionColor,
          side: BorderSide(
            color: isDark ? const Color(0xFF44554E) : const Color(0xFFCBC4B7),
          ),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: actionColor,
        foregroundColor: isDark ? const Color(0xFF10201B) : Colors.white,
      ),
    );
  }

  ThemeMode _themeModeFromStorage(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  String _themeModeToStorage(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}