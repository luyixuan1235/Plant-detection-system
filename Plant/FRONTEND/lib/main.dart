import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/login_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const LibrarySeatApp());
}

class LibrarySeatApp extends StatefulWidget {
  const LibrarySeatApp({super.key});

  @override
  State<LibrarySeatApp> createState() => _LibrarySeatAppState();
}

class _LibrarySeatAppState extends State<LibrarySeatApp> {
  Locale _locale = const Locale('en', '');

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code');
    final countryCode = prefs.getString('country_code');
    if (languageCode == null || !mounted) return;
    setState(() {
      _locale = Locale(languageCode, countryCode);
    });
  }

  Future<void> _handleLocaleChange(Locale value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', value.languageCode);
    if (value.countryCode == null || value.countryCode!.isEmpty) {
      await prefs.remove('country_code');
    } else {
      await prefs.setString('country_code', value.countryCode!);
    }
    if (!mounted) return;
    setState(() {
      _locale = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plant Monitoring System',
      theme: AppTheme.light(),
      locale: _locale,
      supportedLocales: const [
        Locale('en', ''),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: LoginPage(onLocaleChange: _handleLocaleChange),
    );
  }
}
