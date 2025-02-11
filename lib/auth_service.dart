// auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl;

  AuthService._(this.baseUrl); // 私有构造函数

  // 工厂构造函数，用于创建 AuthService 的实例
  static Future<AuthService> create(String baseUrl) async {
    final authService = AuthService._(baseUrl);
    return authService;
  }

   // 获取 Token
  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 设置 Token
  Future<void> setToken(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }
    // 删除 Token
  Future<void> removeToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
       // 登录成功，保存 Token
      await setToken(responseData['token']);
       print('Token saved: ${responseData['token']}');
      return responseData; // 返回整个响应数据
    } else {
      print('登录失败: ${response.statusCode}, ${response.body}'); // 调试信息
      return null;
    }
  }
}