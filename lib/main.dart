import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'user_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // 状态栏透明
    statusBarIconBrightness: Brightness.dark, // 根据背景颜色调整图标亮度
    statusBarBrightness: Brightness.light, // 根据背景颜色调整 (iOS)
    systemNavigationBarColor: Color(0xFFF7FAFC), //  ✅  导航栏颜色
    systemNavigationBarIconBrightness: Brightness.light, //  ✅  导航栏图标颜色
  ));

  runApp(
    ChangeNotifierProvider(
      create: (context) => UserData(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
   const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '鸿雁心笺',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
          primary: Colors.blue, // 主色
          onPrimary: Colors.white, // 主色上的文本颜色
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, // AppBar 背景色
          titleTextStyle:
              TextStyle(color: Colors.black87, fontFamily: 'MiSans'),
          iconTheme: IconThemeData(color: Colors.black87),
          elevation: 1,
        ),
        fontFamily: 'MiSans',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue, // 按钮背景色
            foregroundColor: Colors.white, // 按钮文本颜色
          ),
        ),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
          foregroundColor: Colors.blue,
        )),
      ),
      home: const LoginScreen(),
    );
  }
}