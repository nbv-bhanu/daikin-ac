import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/ac_control_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const DaikinApp());
}

class DaikinApp extends StatelessWidget {
  const DaikinApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Daikin AC',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0078D7), brightness: Brightness.dark),
      useMaterial3: true,
    ),
    home: const AcControlScreen(),
  );
}
