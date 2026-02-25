import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'models/app_preferences.dart';
import 'screens/contact_list_screen.dart';
import 'services/database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows) {
    // Initialize FFI for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const HesabakApp());
}

class HesabakApp extends StatefulWidget {
  const HesabakApp({super.key});

  @override
  State<HesabakApp> createState() => _HesabakAppState();
}

class _HesabakAppState extends State<HesabakApp> {
  ThemeMode _themeMode = ThemeMode.system;
  AppLanguageMode _languageMode = AppLanguageMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await DatabaseHelper.instance.getThemeMode();
    final languageMode = await DatabaseHelper.instance.getLanguageMode();
    if (!mounted) return;
    setState(() {
      _themeMode = mode;
      _languageMode = languageMode;
    });
  }

  Future<void> _updateThemeMode(ThemeMode mode) async {
    await DatabaseHelper.instance.setThemeMode(mode);
    if (!mounted) return;
    setState(() {
      _themeMode = mode;
    });
  }

  Future<void> _updateLanguageMode(AppLanguageMode mode) async {
    await DatabaseHelper.instance.setLanguageMode(mode);
    if (!mounted) return;
    setState(() {
      _languageMode = mode;
    });
  }

  Locale? get _locale {
    return switch (_languageMode) {
      AppLanguageMode.system => null,
      AppLanguageMode.en => const Locale('en'),
      AppLanguageMode.fa => const Locale('fa'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حسابک',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [
        Locale('en'),
        Locale('fa'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: ContactListScreen(
        onThemeModeChanged: _updateThemeMode,
        onLanguageModeChanged: _updateLanguageMode,
      ),
    );
  }
}
