import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'user_data.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

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
      builder: (context, child) {
        // 将所有页面包装在WithICP组件中
        return WithICP(child: child!);
      },
    );
  }
}

// 包装组件，为所有页面添加备案信息
class WithICP extends StatelessWidget {
  final Widget child;
  
  const WithICP({Key? key, required this.child}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸信息
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    
    // 检测child的背景颜色
    final backgroundColor = _detectBackgroundColor(context, child);
    
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // 主内容区域 - 确保至少占满一屏
                SizedBox(
                  // 强制高度为屏幕高度，确保必须下滑才能看到备案号
                  height: screenHeight,
                  width: screenWidth,
                  child: child,
                ),
                
                // 备案号 - 在内容下方，需要滚动才能看到
                ICPFooter(
                  icpNumber: '粤ICP备2025382502号',
                  icpUrl: 'https://beian.miit.gov.cn/',
                  backgroundColor: backgroundColor,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  // 尝试检测页面的背景颜色
  Color _detectBackgroundColor(BuildContext context, Widget child) {
    // 默认使用主题的脚手架背景颜色
    Color defaultColor = Theme.of(context).scaffoldBackgroundColor;
    
    // 检查child是否为Scaffold
    if (child is Scaffold) {
      if (child.backgroundColor != null && child.backgroundColor != Colors.transparent) {
        return child.backgroundColor!;
      }
    }
    
    return defaultColor;
  }
}

// 备案号底部组件
class ICPFooter extends StatelessWidget {
  final String icpNumber;
  final String? icpUrl;
  final Color? backgroundColor;
  
  const ICPFooter({
    Key? key,
    required this.icpNumber,
    this.icpUrl,
    this.backgroundColor,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 获取当前上下文的样式和颜色
    final theme = Theme.of(context);
    final effectiveBackgroundColor = backgroundColor ?? theme.scaffoldBackgroundColor;
    
    // 计算文本颜色，根据背景色亮度自动调整
    final textColor = _getTextColorForBackground(effectiveBackgroundColor);
    
    return InkWell(
      onTap: () async {
        if (icpUrl != null) {
          if (kIsWeb) {
            html.window.open(icpUrl!, '_blank');
          } else {
            final Uri url = Uri.parse(icpUrl!);
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        // 使用与页面相同的背景颜色，实现沉浸式效果
        color: effectiveBackgroundColor,
        alignment: Alignment.center,
        child: Text(
          icpNumber,
          style: TextStyle(
            fontSize: 12,
            color: textColor,
          ),
        ),
      ),
    );
  }
  
  // 根据背景色计算适合的文本颜色
  Color _getTextColorForBackground(Color backgroundColor) {
    // 计算颜色亮度 (0-1)
    final brightness = backgroundColor.computeLuminance();
    
    // 根据背景亮度返回适合的文本颜色
    if (brightness > 0.5) {
      // 背景是亮色，使用深色文本
      return const Color(0x99666666);
    } else {
      // 背景是暗色，使用亮色文本
      return const Color(0x99EEEEEE);
    }
  }
}