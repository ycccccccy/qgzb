import 'package:flutter/material.dart';
import 'package:hyxj/email_tips.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen_main.dart';
import 'register_screen.dart';
import 'package:flutter/services.dart';
import 'simple_captcha.dart';

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

// 忘记密码联系方式
const String _contactInfo =
    '联系管理员：\n微信:\nx2463274\n邮箱:\n3646834681@qq.com\nliujingxuan200705@163.com';

class LoginScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialPassword;

  const LoginScreen({super.key, this.initialEmail, this.initialPassword});

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
  bool _autoLogin = false; // 这个变量用来控制 UI 上的显示
  String? _loginError;
  String? _captchaError;
  late SharedPreferences _prefs;

  String? _selectedSchool;
  String? _selectedGrade;
  int? _selectedClass;
  String? _rememberedId;
  String? _rememberedName;

  bool _initialLoginAttempted = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedData(); // 加载记住的数据
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialLoginAttempted) {
      _initialLoginAttempted = true;
      _loadSharedPreferencesAndAttemptAutoLogin(); // 加载 SharedPreferences 并尝试自动登录
    }
  }

    Future<void> _loadSharedPreferencesAndAttemptAutoLogin() async {
    _prefs = await SharedPreferences.getInstance();
    _rememberMe = _prefs.getBool(_rememberMeKey) ?? false;
    _autoLogin = _prefs.getBool(_autoLoginKey) ?? false; // 从 SharedPreferences 读取

    if (_autoLogin) {
      await _login(null); // 自动登录 (无验证码)
    }
      setState(() {});

  }

  // 加载记住的数据
  Future<void> _loadRememberedData() async {
    _prefs = await SharedPreferences.getInstance();
    if (_prefs.getBool(_rememberMeKey) == true ||
        _prefs.getBool(_autoLoginKey) == true) {
      _emailController.text = _prefs.getString(_rememberedEmailKey) ?? '';
      _passwordController.text = _prefs.getString(_rememberedPasswordKey) ?? '';
      _selectedSchool = _prefs.getString(_selectedSchoolKey);
      _selectedGrade = _prefs.getString(_selectedGradeKey);
      _selectedClass = _prefs.getInt(_selectedClassKey);
      _rememberedId = _prefs.getString(_rememberedIdKey);
      _rememberedName = _prefs.getString(_rememberedNameKey);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

// 保存“记住我”和“自动登录”选项 (现在只保存记住我)
  Future<void> _saveRememberMe() async {
    await _prefs.setBool(_rememberMeKey, _rememberMe);
    //await _prefs.setBool(_autoLoginKey, _autoLogin);  // 不要在这里设置 _autoLogin

    if (_rememberMe) {
      await _prefs.setString(_rememberedEmailKey, _emailController.text.trim());
      await _prefs.setString(_rememberedPasswordKey, _passwordController.text);
      await _prefs.setString(_selectedSchoolKey, _selectedSchool ?? '');
      await _prefs.setString(_selectedGradeKey, _selectedGrade ?? '');
      await _prefs.setInt(_selectedClassKey, _selectedClass ?? 0);
      await _prefs.setString(_rememberedIdKey, _rememberedId ?? '');
      await _prefs.setString(_rememberedNameKey, _rememberedName ?? '');
    } else {
      await _prefs.remove(_rememberedEmailKey);
      await _prefs.remove(_rememberedPasswordKey);
      await _prefs.remove(_selectedSchoolKey);
      await _prefs.remove(_selectedGradeKey);
      await _prefs.remove(_selectedClassKey);
      await _prefs.remove(_rememberedIdKey);
      await _prefs.remove(_rememberedNameKey);
      // 如果取消记住我，也应该移除自动登录
      await _prefs.remove(_autoLoginKey);
    }
  }

    // 处理登录 (按钮点击)
    Future<void> _handleLogin() async {
      if (!_formKey.currentState!.validate()) {
        return;
      }
      setState(() {
        _loginError = null;
      });
      _showCaptchaDialog(); // 显示验证码
    }

  // 显示验证码对话框
  Future<void> _showCaptchaDialog() async {
    final captchaResult = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('验证'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              SimpleCaptcha(
                isDialog: true,
                onCompleted: (value) {
                  Navigator.of(context).pop(value); // 返回验证码
                },
                errorMessage: _captchaError,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null); // 取消
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    if (captchaResult != null) {
      await _login(captchaResult); // 使用验证码登录
    }
  }

  // 实际登录逻辑
  Future<void> _login(String? captchaCode) async {
    if (_isLoading) return; // 防止多次登录尝试
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final res = await Supabase.instance.client.auth
          .signInWithPassword(
            email: email,
            password: password,
          )
          .timeout(Duration(seconds: 30));

      if (res.user != null && mounted) {
        final userData = await _fetchUserData(res.user!.id); // 获取用户信息

        if (userData != null) {
          _selectedSchool = userData['school'] as String?;
          _selectedGrade = userData['grade'] as String?;
          _selectedClass = userData['class_number'] as int?;
          _rememberedId = userData['student_id'] as String?;
          _rememberedName = userData['name'] as String?;

          await _prefs.setString(_currentUserIdKey, res.user!.id);

           // 登录成功后，根据 _rememberMe 的值决定是否设置 _autoLoginKey
          if (_rememberMe) {
            await _prefs.setBool(_autoLoginKey, true);
          }
        flg = true;
          // 检查 widget 是否仍然 mounted
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
      } else if (mounted) {
        setState(() {
          _loginError = '邮箱或密码不正确';
        });
      }
    } catch (e) {
      print('登录错误: $e');
      if (mounted) {
        setState(() {
          if (e is AuthException) {
            _loginError = (e.message.contains('Invalid login credentials'))
                ? '邮箱或密码不正确'
                : (e.message.contains('Email not confirmed'))
                    ? '邮箱未验证'
                    : '登录失败：${e.message}';
          } else {
            _loginError = '未知错误';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 从数据库获取用户信息
  Future<Map<String, dynamic>?> _fetchUserData(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('students')
          .select('school, class_name, student_id, name, auth_user_id')
          .eq('auth_user_id', userId)
          .single();

      if (response == false) {
        return null;
      }

      // 从 class_name 中提取年级和班级
      String className = response['class_name'] as String;
      String? grade;
      int? classNumber;

      final gradeMatch = RegExp(r'(高[一二三]|初[一二三])').firstMatch(className);
      if (gradeMatch != null) {
        grade = gradeMatch.group(0); // 年级
      }

      final classMatch = RegExp(r'(\d+)').firstMatch(className);
      if (classMatch != null) {
        classNumber = int.tryParse(classMatch.group(0)!); // 班级
      }

      return {
        'school': response['school'] as String,
        'grade': grade,
        'class_number': classNumber,
        'student_id': response['student_id'] as String,
        'name': response['name'] as String,
      };
    } catch (e) {
      print("获取数据失败: $e");
      return null;
    }
  }

  // 显示错误SnackBar
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

  // 显示“忘记密码”对话框
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
                      // 显示登录错误
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
                              // if (!_rememberMe) {  // 不需要这个了
                              //   _autoLogin = false;
                              // }
                            });
                            _saveRememberMe(); // 保存
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
                              _autoLogin = value!;  // 直接更新 UI 显示
                              // if (_autoLogin) {   // 不需要这个了
                              //    _rememberMe = true;
                              //}
                            });
                           // _saveRememberMe();  //  在这里不需要保存 _autoLogin 的状态
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
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _showContactDialog, // 忘记密码
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
                                  builder: (context) => const RegisterScreen()),
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