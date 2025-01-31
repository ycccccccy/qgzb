// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://bydbvhsknggjkyifhywq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5ZGJ2aHNrbmdnamt5aWZoeXdxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyOTk5NjQ4MiwiZXhwIjoyMDQ1NTcyNDgyfQ._83EQF_RaXn63-q7Gh8xj36FmoIFQnTGYCohljOnHGE',
  );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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
          titleTextStyle: TextStyle(color: Colors.black87), 
          iconTheme: IconThemeData(color: Colors.black87), 
          elevation: 1, 
        ),
      ),
      home: LoginScreen(),
    );
  }
}