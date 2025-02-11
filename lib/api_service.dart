import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class ApiService {
  final String baseUrl = 'http://120.25.174.114:5000'; // 开发环境

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> setToken(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> removeToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

//-------LoginScreen 和 RegisterScreen 相关的方法-------

  // 登录 (发送明文密码)
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}), // 明文
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(utf8.decode(response.bodyBytes)); // 使用 utf8.decode
      await setToken(responseData['token']);
      return responseData;
    } else {
      //  这里也要修改
      throw Exception(
          '登录失败: ${response.statusCode}, ${jsonDecode(utf8.decode(response.bodyBytes))['message']}');
    }
  }

  // 获取用户信息
  Future<User> getUserInfo(int userId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('未登录');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception(
          '获取用户信息失败: ${response.statusCode}, ${jsonDecode(utf8.decode(response.bodyBytes))['message']}');
    }
  }

  // 注册第一步：发送注册请求 (发送明文密码)
  Future<void> registerStep1({
    required String email,
    required String studentId,
    required String name,
    required String school,
    required String className,
    required String password, // 明文
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'studentId': studentId,
        'name': name,
        'school': school,
        'className': className,
        'password': password, // 明文
      }),
    );

    if (response.statusCode != 200) {
      String errorMessage = '注册失败';
      try {
        final Map<String, dynamic> errorData = jsonDecode(utf8.decode(response.bodyBytes));
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (e) {}
      throw Exception(errorMessage);
    }
  }

  // 注册第二步：验证邮箱验证码,获取 verification_token
  Future<String> verifyEmailCode(String email, String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verify-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      return responseData['verification_token'];
    } else {
      String errorMessage = '验证码错误';
      try {
        final Map<String, dynamic> errorData = jsonDecode(utf8.decode(response.bodyBytes));
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (e) {
        // 解析错误消息失败
      }
      throw Exception(errorMessage);
    }
  }

  // 注册第三步：创建用户 (发送明文密码)
  Future<Map<String, dynamic>> createUser({
    required String email,
    required String studentId,
    required String name,
    required String school,
    required String className,
    required String password, // 明文
    required String verificationToken,
  }) async {

    final response = await http.post(
      Uri.parse('$baseUrl/create-user'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'studentId': studentId,
        'name': name,
        'school': school,
        'className': className,
        'password': password, // 明文
        'verification_token': verificationToken,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      String errorMessage = '创建用户失败';
      try {
        final Map<String, dynamic> errorData =  jsonDecode(utf8.decode(response.bodyBytes));
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (e) {}
      throw Exception(errorMessage);
    }
  }


//-------其他和信件有关的api-------
  Future<Map<String, dynamic>> createLetter(Letter letter) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    final response = await http.post(
      Uri.parse('$baseUrl/letters'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(letter.toJson()),
    );
    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('创建信件失败: ${response.statusCode}, ${jsonDecode(utf8.decode(response.bodyBytes))['message']}');
    }
  }

// 获取用户发送的信件
  Future<List<Letter>> getSentLetters({int page = 0, int pageSize = 10}) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    final response = await http.get(
      Uri.parse('$baseUrl/letters?page=$page&pageSize=$pageSize'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((item) => Letter.fromJson(item)).toList();
    } else {
      throw Exception('获取信件列表失败: ${response.statusCode}, ${jsonDecode(utf8.decode(response.bodyBytes))['message']}');
    }
  }

// 获取用户收件箱信件
  Future<List<Letter>> getReceivedLetters({
    int page = 0,
    int pageSize = 10,
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    final response = await http.get(
      Uri.parse('$baseUrl/received_letters?page=$page&pageSize=$pageSize'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((item) => Letter.fromJson(item)).toList();
    } else {
      throw Exception('获取收到的信件列表失败: ${response.statusCode}, ${jsonDecode(utf8.decode(response.bodyBytes))['message']}');
    }
  }

// 根据信件id获取信件
  Future<Letter> getLetterById(String letterId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('未登录');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/letters/$letterId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return Letter.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('获取信件失败: ${response.statusCode}, ${jsonDecode(utf8.decode(response.bodyBytes))['message']}');
    }
  }

// 获取最近联系人
  Future<List<String>> getRecentContacts() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    final response = await http.get(
      Uri.parse('$baseUrl/recent_contacts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((item) => item.toString()).toList();
    } else {
      throw Exception('获取最近联系人失败: ${response.statusCode}, ${jsonDecode(utf8.decode(response.bodyBytes))['message']}');
    }
  }

  // 根据 studentId 和 name 获取学生数据 (用于 _loadMySchoolAndName)
  Future<Map<String, dynamic>?> fetchStudentData(
      String studentId, String name) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('未登录');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/students?studentId=$studentId&name=$name'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String,dynamic> data = jsonDecode(utf8.decode(response.bodyBytes)); // 直接解码成 Map
      return data;

    } else {
      throw Exception(
          '获取学生数据失败: ${response.statusCode}, ${jsonDecode(utf8.decode(response.bodyBytes))['message']}');
    }
  }

  // 模糊搜索用户
  Future<List<Map<String, dynamic>>> searchUsers(String name) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    final response = await http.get(
      Uri.parse('$baseUrl/search_users?name=$name'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // 认证
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('搜索用户失败: ${response.statusCode}, ${jsonDecode(utf8.decode(response.bodyBytes))['message']}');
    }
  }

  // 检查 AI 访问权限 
    Future<bool> checkAIAccess() async {
    final token = await getToken();
    if (token == null) {
      return false; // 未登录，没有权限
    }

    final response = await http.get(
      Uri.parse('$baseUrl/check_ai_access'), // 调用 Flask 的 /check_ai_access 路由
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['has_access'] ?? false; // 从服务器响应中获取 has_access 字段
    } else {
      // 处理错误，例如服务器不可用或返回错误状态码
      print('检查 AI 权限失败: ${response.statusCode}');
      return false; // 假设出错时没有权限
    }
  }
}