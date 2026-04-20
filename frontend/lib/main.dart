import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Safely load dotenv if it exists, otherwise ignore (it will fallback to defaults)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Notice: .env file not found, using default URL.");
  }

  runApp(const KaquizApp());
}

class KaquizApp extends StatelessWidget {
  const KaquizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kaquiz Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginScreen(),
    );
  }
}
