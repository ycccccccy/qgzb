import 'package:flutter/material.dart';
import 'package:hyxj/email_tips.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen_main.dart';
import 'register_screen.dart';
import 'api_service.dart'; 

// SharedPreferences Key 常量
const String _rememberMeKey = 'rememberMe';
const String _autoLoginKey = 'autoLogin';
const String _rememberedEmailKey = 'rememberedEmail';
const String _rememberedPasswordKey = 'rememberedPassword';
const String _currentUserIdKey = 'current_user_id';
const String _selectedSchoolKey = 'selectedSchool';
const String _selectedGradeKey = 'selectedGrade';
const String _selectedClassKey = 'selectedClass';
const String _rememberedIdKey = 'rememberedId';
const String _rememberedNameKey = 'rememberedName';
const String _saltKey = 'salt';
const String _passwordKey = 'password';

const String _contactInfo =
    '联系管理员：\n微信:\nx2463274\n邮箱:\n3646834681@qq.com\nliujingxuan200705@163.com';

class LoginScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialPassword;

  const LoginScreen({Key? key, this.initialEmail, this.initialPassword})
      : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _autoLogin = false;
  String? _loginError;
  late SharedPreferences _prefs;
  String? _selectedSchool;
  String? _selectedGrade;
  int? _selectedClass;
  String? _rememberedId;
  String? _rememberedName;
  String? _salt;
  String? _password;
  bool _initialLoginAttempted = false;
  final _apiService = ApiService(); // 使用 ApiService


  @override
  void initState() {
    super.initState();
    _loadRememberedData(); // 加载记住的数据
  }

  // 移除 _initializeAuthService 方法

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialLoginAttempted) {
      _initialLoginAttempted = true;
      _loadSharedPreferencesAndAttemptAutoLogin();
    }
  }

  Future<void> _loadSharedPreferencesAndAttemptAutoLogin() async {
    _prefs = await SharedPreferences.getInstance();
    _rememberMe = _prefs.getBool(_rememberMeKey) ?? false;
    _autoLogin = _prefs.getBool(_autoLoginKey) ?? false;
    _emailController.text = _prefs.getString(_rememberedEmailKey) ?? '';
    _passwordController.text = _prefs.getString(_rememberedPasswordKey) ?? '';

    if (_autoLogin) {
      if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
        await _login();
      }
    }
    setState(() {});
  }

  Future<void> _loadRememberedData() async {
    _prefs = await SharedPreferences.getInstance();
    _emailController.text = _prefs.getString(_rememberedEmailKey) ?? '';
    _passwordController.text = _prefs.getString(_rememberedPasswordKey) ?? '';
    _selectedSchool = _prefs.getString(_selectedSchoolKey);
    _selectedGrade = _prefs.getString(_selectedGradeKey);
    _selectedClass = _prefs.getInt(_selectedClassKey);
    _rememberedId = _prefs.getString(_rememberedIdKey);
    _rememberedName = _prefs.getString(_rememberedNameKey);
    _salt = _prefs.getString(_saltKey);
    _password = _prefs.getString(_passwordKey);
    _rememberMe = _prefs.getBool(_rememberMeKey) ?? false;
    _autoLogin = _prefs.getBool(_autoLoginKey) ?? false;

    setState(() {});
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveRememberMe() async {
    await _prefs.setBool(_rememberMeKey, _rememberMe);

    if (_rememberMe) {
      await _prefs.setString(_rememberedEmailKey, _emailController.text.trim());
      await _prefs.setString(_rememberedPasswordKey, _passwordController.text);
      await _prefs.setString(_selectedSchoolKey, _selectedSchool ?? '');
      await _prefs.setString(_selectedGradeKey, _selectedGrade ?? '');
      await _prefs.setInt(_selectedClassKey, _selectedClass ?? 0);
      await _prefs.setString(_rememberedIdKey, _rememberedId ?? '');
      await _prefs.setString(_rememberedNameKey, _rememberedName ?? '');
      await _prefs.setString(_saltKey, _salt ?? '');
      await _prefs.setString(_passwordKey, _password ?? '');
    } else {
      await _prefs.remove(_rememberedEmailKey);
      await _prefs.remove(_rememberedPasswordKey);
      await _prefs.remove(_selectedSchoolKey);
      await _prefs.remove(_selectedGradeKey);
      await _prefs.remove(_selectedClassKey);
      await _prefs.remove(_rememberedIdKey);
      await _prefs.remove(_rememberedNameKey);
      await _prefs.remove(_autoLoginKey);
      await _prefs.remove(_saltKey);
      await _prefs.remove(_passwordKey);
    }
  }

  Future<void> _saveAutoLogin() async {
    await _prefs.setBool(_autoLoginKey, _autoLogin);
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loginError = null;
    });
    await _saveRememberMe();
    await _saveAutoLogin();
    await _login();
  }

  Future<void> _login() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // 使用 ApiService 登录
      final loginResult = await _apiService.login(email, password);


        final userId = loginResult['userId'];
      // 保存 userId
      await _prefs.setString(_currentUserIdKey, userId.toString());

      // 获取并保存用户数据
      final userData = await _fetchUserData(userId
          .toString()); // _fetchUserData 仍然直接使用 http，稍后会修改
      if (userData != null) {
        _selectedSchool = userData['school'] as String?;
        _selectedGrade = userData['grade'] as String?;
        _selectedClass = userData['class_number'] as int?;
        _rememberedId = userData['student_id'] as String?;
        _rememberedName = userData['name'] as String?;
        _salt = userData['salt'] as String?;
        _password = userData['password'] as String?;

        //如果记住我，就保存
        if (_rememberMe) {
          await _saveRememberMe();
        }
        // 如果勾选了自动登录，则保存自动登录状态
        if (_autoLogin) {
          await _prefs.setBool(_autoLoginKey, true);
        }

        flg = true; // 假设 flg 是一个全局变量
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreenMain()),
          );
        }
      } else {
        if (mounted) {
          _showErrorSnackBar("获取用户信息失败, 请联系管理员");
        }
      }
        } catch (e) {
      print('登录错误: $e');
      if (mounted) {
        setState(() {
          _loginError = e.toString(); // 显示详细的错误信息
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

// 修改 _fetchUserData，使用 ApiService
  Future<Map<String, dynamic>?> _fetchUserData(String userId) async {
    try {
      final user = await _apiService.getUserInfo(int.parse(userId)); // 使用 ApiService

      // 从 User 对象中提取数据
      String className = user.className;
      String? grade;
      int? classNumber;

      final gradeMatch = RegExp(r'(高[一二三]|初[一二三])').firstMatch(className);
      if (gradeMatch != null) {
        grade = gradeMatch.group(0);
      }

      final classMatch = RegExp(r'(\d+)').firstMatch(className);
      if (classMatch != null) {
        classNumber = int.tryParse(classMatch.group(0)!);
      }

      return {
        'school': user.school,
        'grade': grade,
        'class_number': classNumber,
        'student_id': user.studentId,
        'name': user.name,
        'salt': user.salt,
        'password': user.password,
      };
    } catch (e) {
      print("获取数据失败: $e");
      return null;
    }
  }


  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('忘记密码？'),
          content: const Text(_contactInfo),
          actions: <Widget>[
            TextButton(
              child: const Text('关闭'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 4,
            color: Colors.grey[50],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '欢迎登录',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        hintText: '请输入你的邮箱',
                        prefixIcon: Icon(Icons.email),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '邮箱不能为空';
                        }
                        if (!value.contains('@')) {
                          return '邮箱格式不正确';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: '密码',
                        hintText: '请输入你的密码',
                        prefixIcon: const Icon(Icons.lock),
                        filled: true,
                        fillColor: Colors.white,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(_passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                        ),
                      ),
                      obscureText: !_passwordVisible,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '密码不能为空';
                        }
                        if (value.length < 6) {
                          return '密码长度至少为6位';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    if (_loginError != null) ...[
                      Text(
                        _loginError!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value!;
                            });
                          },
                        ),
                        Text(
                          '记住我',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 16),
                        Checkbox(
                          value: _autoLogin,
                          onChanged: (value) {
                            setState(() {
                              _autoLogin = value!;
                            });
                          },
                        ),
                        Text(
                          '自动登录',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('登录',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _showContactDialog,
                          child: const Text(
                            '忘记密码？',
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const RegisterScreen()),
                            );
                          },
                          child: const Text(
                            '没有账号？去注册',
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}