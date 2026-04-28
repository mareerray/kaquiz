import 'package:flutter/material.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Safely load dotenv if it exists, otherwise ignore (it will fallback to defaults)
 // Step 1: Load .env FIRST
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("🟢 ENV loaded");
    debugPrint("🟢 SUPABASE_URL = ${dotenv.env['SUPABASE_URL']}");
    debugPrint("🟢 SUPABASE_KEY exists = ${dotenv.env['SUPABASE_KEY'] != null}");
  } catch (e) {
    debugPrint("🔴 ENV load failed: $e");
  }

  // Step 2: Now it's safe to use dotenv values
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_KEY'] ?? '',
    );
    debugPrint("🟢 Supabase initialized");
  } catch (e) {
    debugPrint("🔴 Supabase init failed: $e");
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
