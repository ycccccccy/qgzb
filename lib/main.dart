import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'user_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bydbvhsknggjkyifhywq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5ZGJ2aHNrbmdnamt5aWZoeXdxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyOTk5NjQ4MiwiZXhwIjoyMDQ1NTcyNDgyfQ._83EQF_RaXn63-q7Gh8xj36FmoIFQnTGYCohljOnHGE',
  );

  Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
    final AuthChangeEvent eventType = event.event;
    final prefs = await SharedPreferences.getInstance();
    if (eventType == AuthChangeEvent.signedOut) {
      final userData = UserData();
      userData.clear();
      await prefs.remove('current_user_id');
      await prefs.remove('rememberedName');
      await prefs.remove('rememberedId');
    } else if (eventType == AuthChangeEvent.signedIn ||
        eventType == AuthChangeEvent.tokenRefreshed) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await prefs.setString('current_user_id', user.id);
        await prefs.setString('rememberedName', user.userMetadata?['name'] as String? ?? '');
        await prefs.setString('rememberedId', user.userMetadata?['student_id'] as String? ?? '');
      }
    }
  });

  runApp(
    ChangeNotifierProvider(
      create: (context) => UserData(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '鸿雁心笺',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
          primary: Colors.blue,
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          titleTextStyle: TextStyle(color: Colors.black87, fontFamily: 'MiSans'),
          iconTheme: IconThemeData(color: Colors.black87),
          elevation: 1,
        ),
        fontFamily: 'MiSans',
      ),
      home: const LoginScreen(),
    );
  }
}