import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pages/shell_page.dart';

/// 应用根组件，统一主题与导航结构。
class PersonalRecordApp extends StatelessWidget {
  const PersonalRecordApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );
    final baseTextTheme = GoogleFonts.notoSansScTextTheme();

    return MaterialApp(
      title: '个人信息记录',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        textTheme: baseTextTheme,
        scaffoldBackgroundColor: const Color(0xFFF3F1EB),
        canvasColor: const Color(0xFFF3F1EB),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 0,
          titleTextStyle: baseTextTheme.titleLarge?.copyWith(
            color: const Color(0xFF16302B),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFAF8F3),
          labelStyle: const TextStyle(color: Color(0xFF5B6964)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD7D1C5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD7D1C5)),
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
        dividerColor: const Color(0xFFD9D3C8),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF16302B),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF16302B),
            side: const BorderSide(color: Color(0xFFCBC4B7)),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF16302B),
          foregroundColor: Colors.white,
        ),
      ),
      home: const AppShellPage(),
    );
  }
}