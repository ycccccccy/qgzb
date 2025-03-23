import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart'; // 添加加密库
import 'package:encrypt/encrypt.dart'; // 添加加密库
import 'package:pointycastle/asymmetric/api.dart'; // 添加这一行导入
import 'models.dart';

class ApiService {
  final String baseUrl = 'http://120.25.174.114:5000'; // 开发环境
  //final String baseUrl = 'http://172.17.26.204:5000'; // 本地环境
  //final String baseUrl = 'https://hongyanink.cn/api';   //  生产环境, 使用 HTTPS

  // 生成随机会话密钥
  String _generateSessionKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }
  
  // 对消息进行加密
  Map<String, String> _encryptMessage(String message, String serverPublicKey) {
    // 生成随机会话密钥
    final sessionKey = _generateSessionKey();
    
    // 使用会话密钥加密消息
    final key = Key.fromUtf8(sessionKey.substring(0, 32).padRight(32, '0'));
    final iv = IV.fromLength(16);
    final encrypter = Encrypter(AES(key));
    final encryptedMessage = encrypter.encrypt(message, iv: iv).base64;
    
    // 使用服务器公钥加密会话密钥
    final publicKey = RSAKeyParser().parse(serverPublicKey) as RSAPublicKey;
    final rsaEncrypter = Encrypter(RSA(publicKey: publicKey));
    final encryptedSessionKey = rsaEncrypter.encrypt(sessionKey).base64;
    
    return {
      'encryptedMessage': encryptedMessage,
      'encryptedSessionKey': encryptedSessionKey,
      'iv': iv.base64
    };
  }
  
  // 解密消息
  String _decryptMessage(String encryptedMessage, String sessionKey, String iv) {
    final key = Key.fromUtf8(sessionKey.substring(0, 32).padRight(32, '0'));
    final ivObj = IV.fromBase64(iv);
    final encrypter = Encrypter(AES(key));
    return encrypter.decrypt64(encryptedMessage, iv: ivObj);
  }

  // 获取服务器加密公钥
  Future<String> _getServerPublicKey() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    final response = await http.get(
      Uri.parse('$baseUrl/encryption_key'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    
    if (response.statusCode != 200) {
      throw Exception('获取加密密钥失败');
    }
    
    return jsonDecode(utf8.decode(response.bodyBytes))['public_key'];
  }

  // 哈希密码
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

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

  // 登录函数 - 直接发送原始密码并在失败时抛出异常
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password, // 直接发送原始密码
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      await setToken(responseData['token']);
      return responseData; // 返回包含token和userId的数据
    } else {
      // 抛出异常而不是返回null
      String errorMessage = '登录失败';
      try {
        final Map<String, dynamic> errorData = jsonDecode(utf8.decode(response.bodyBytes));
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (e) {}
      throw Exception(errorMessage);
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

  // 注册第一步：发送注册请求 (直接发送原始密码)
  Future<void> registerStep1({
    required String email,
    required String studentId,
    required String name,
    required String school,
    required String className,
    required String password,
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
        'password': password, // 直接发送原始密码，不做哈希处理
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

  // 注册第三步：创建用户 (哈希密码)
  Future<Map<String, dynamic>> createUser({
    required String email,
    required String studentId,
    required String name,
    required String school,
    required String className,
    required String password,
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
        'password': password, // 直接发送原始密码
        'verification_token': verificationToken,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      String errorMessage = '创建用户失败';
      try {
        final Map<String, dynamic> errorData = jsonDecode(utf8.decode(response.bodyBytes));
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (e) {}
      throw Exception(errorMessage);
    }
  }


//-------其他和信件有关的api-------
  // 创建加密信件
  Future<Map<String, dynamic>> createLetter(Letter letter) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('未登录');
    }
    
    try {
      // 获取服务器公钥
      final serverPublicKey = await _getServerPublicKey();
      
      // 加密信件内容
      final encryptionData = _encryptMessage(letter.content, serverPublicKey);
      
      // 创建带有加密内容的信件
      final encryptedLetter = Letter(
        id: letter.id,
        senderId: letter.senderId,
        receiverName: letter.receiverName,
        receiverClass: letter.receiverClass,
        content: encryptionData['encryptedMessage']!, // 加密后的内容
        sendTime: letter.sendTime,
        isAnonymous: letter.isAnonymous,
        mySchool: letter.mySchool,
        targetSchool: letter.targetSchool,
        senderName: letter.senderName,
        isRead: letter.isRead,
      );
      
      // 发送加密信件和加密的会话密钥
      final response = await http.post(
        Uri.parse('$baseUrl/letters'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'letter': encryptedLetter.toJson(),
          'encrypted_session_key': encryptionData['encryptedSessionKey'],
          'iv': encryptionData['iv'],
          'is_encrypted': true // 标记此信件为加密格式
        }),
      );
      
      if (response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('创建信件失败: ${response.statusCode}, ${jsonDecode(utf8.decode(response.bodyBytes))['message']}');
      }
    } catch (e) {
      // 如果加密过程发生错误，则回退到未加密模式
      print('加密失败，使用未加密模式发送: $e');
      
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
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      
      // 检查是否是加密信件
      if (data['is_encrypted'] == true) {
        try {
          // 信件数据
          final letterData = data['letter'];
          // 服务器解密后重新加密的会话密钥
          final sessionKey = data['session_key'];
          final iv = data['iv'];
          
          // 解密信件内容
          final decryptedContent = _decryptMessage(
            letterData['content'], 
            sessionKey, 
            iv
          );
          
          // 创建解密后的信件对象
          letterData['content'] = decryptedContent;
          return Letter.fromJson(letterData);
        } catch (e) {
          print('解密信件失败: $e');
          // 如果解密失败，返回原始信件（可能会显示加密内容）
          return Letter.fromJson(data);
        }
      } else {
        // 旧格式，未加密的信件
        return Letter.fromJson(data);
      }
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
      return false; // 假设出错时没有权限
    }
  }

// AI 文本生成 (修改为返回 StreamedResponse)
  Future<http.StreamedResponse> generateText({
    required String model,
    required List<Map<String, dynamic>> messages,
    required bool stream,
    required String mode,
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('未登录');
    }

    final url = Uri.parse('$baseUrl/generate_text');
    final request = http.Request('POST', url);

    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });

    request.body = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': stream,
      'mode': mode,
    });


    final response = await request.send();


    if (response.statusCode != 200) {
      throw Exception(
          'AI 生成失败: ${response.statusCode}');
    }

    return response;
  }
}