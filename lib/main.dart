import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const SammlungApp());
}

class SammlungApp extends StatefulWidget {
  const SammlungApp({super.key});
  @override
  State<SammlungApp> createState() => _SammlungAppState();
}

class _SammlungAppState extends State<SammlungApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Beim Verlassen der App sofort speichern (sonst wird mit kurzer Verzögerung gespeichert).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      store.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF35506B),
        secondary: const Color(0xFFE9A23B),
      ),
      scaffoldBackgroundColor: const Color(0xFFF3F4F6),
    );
    return MaterialApp(
      title: 'Sammlung',
      debugShowCheckedModeBanner: false,
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: base.copyWith(textTheme: GoogleFonts.latoTextTheme(base.textTheme)),
      home: const HomePage(),
    );
  }
}
