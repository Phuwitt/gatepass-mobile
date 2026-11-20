import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'controller.dart';
import 'data/api.dart';
import 'ui/login.dart';
import 'ui/workspace.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(GatepassApp(controller: AppController(GatepassApi())));
}

class GatepassApp extends StatefulWidget {
  final AppController controller;
  final int initialTab;
  final ThemeMode themeMode;
  const GatepassApp({
    super.key,
    required this.controller,
    this.initialTab = 0,
    this.themeMode = ThemeMode.light,
  });
  @override
  State<GatepassApp> createState() => _GatepassAppState();
}

class _GatepassAppState extends State<GatepassApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => MaterialApp(
      title: 'GATEPASS',
      themeMode: widget.themeMode,
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: widget.controller.starting
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : widget.controller.authenticated
          ? EmployeeHome(
              controller: widget.controller,
              initialTab: widget.initialTab,
            )
          : LoginScreen(controller: widget.controller),
    ),
  );
}

ThemeData theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: const Color(0xff006f69),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xff9de1cf) : const Color(0xff005f64),
        onPrimary: dark ? const Color(0xff00382f) : Colors.white,
        surface: dark ? const Color(0xff142e3b) : Colors.white,
        onSurface: dark ? const Color(0xffe5eef3) : const Color(0xff183544),
        onSurfaceVariant: dark
            ? const Color(0xffb5c9d2)
            : const Color(0xff526875),
        surfaceContainerHigh: dark
            ? const Color(0xff213d4a)
            : const Color(0xffeaf1f4),
        outlineVariant: dark
            ? const Color(0xff314b58)
            : const Color(0xffdce6ea),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    fontFamily: 'Gatepass',
  );
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xff0b202c) : Colors.white,
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 23,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.55,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      backgroundColor: dark ? const Color(0xff0b202c) : Colors.white,
      titleTextStyle: TextStyle(
        fontFamily: 'Gatepass',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colors.onSurface,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant,
      thickness: 1,
      space: 24,
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      filled: true,
      fillColor: colors.surface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryContainer,
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Gatepass',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        textStyle: const TextStyle(
          fontFamily: 'Gatepass',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      primaryColor: colors.primary,
      brightness: brightness,
      barBackgroundColor: colors.surface,
    ),
  );
}
