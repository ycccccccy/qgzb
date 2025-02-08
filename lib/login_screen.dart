import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen_main.dart'; // 假设的主页
import 'register_screen.dart'; // 假设的注册页面
import 'package:flutter/services.dart';
import 'school_data.dart'; //假设的, 如果你不需要注册功能, 这个可以删掉.
import 'simple_captcha.dart'; // 引入你的 SimpleCaptcha 组件

// 定义 SharedPreferences 的 Key 常量
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

// 忘记密码的联系方式
const String _contactInfo =
    '联系管理员：\n微信:\nx2463274\n邮箱:\n3646834681@qq.com\nliujingxuan200705@163.com';

bool flg = false;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
  String? _loginError; // 用于存储登录错误信息（显示在表单中）
  String? _captchaError;


  late final SharedPreferences _prefs;

  String? _selectedSchool;
  String? _selectedGrade;
  int? _selectedClass;
  String? _rememberedId;
  String? _rememberedName;

  @override
  void initState() {
    super.initState();
    _loadSharedPreferences();
  }
  Future<void> _loadSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _rememberMe = _prefs.getBool(_rememberMeKey) ?? false;
    _autoLogin = _prefs.getBool(_autoLoginKey) ?? false;

    if (_rememberMe || _autoLogin) {
      _emailController.text = _prefs.getString(_rememberedEmailKey) ?? '';
      _passwordController.text = _prefs.getString(_rememberedPasswordKey) ?? '';
      _selectedSchool = _prefs.getString(_selectedSchoolKey);
      _selectedGrade = _prefs.getString(_selectedGradeKey);
      _selectedClass = _prefs.getInt(_selectedClassKey);
      _rememberedId = _prefs.getString(_rememberedIdKey);
      _rememberedName = _prefs.getString(_rememberedNameKey);
    }

    // 自动登录逻辑 (现在需要验证码)
    if (_autoLogin && !flg) {
      _showCaptchaDialog(); // 自动登录也显示验证码
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveRememberMe() async {
    await _prefs.setBool(_rememberMeKey, _rememberMe);
    await _prefs.setBool(_autoLoginKey, _autoLogin);

    if (_rememberMe || _autoLogin) {
      await _prefs.setString(_rememberedEmailKey, _emailController.text);
      await _prefs.setString(_rememberedPasswordKey, _passwordController.text);
      // --- 保存其他数据 ---
      await _prefs.setString(_selectedSchoolKey, _selectedSchool ?? '');
      await _prefs.setString(_selectedGradeKey, _selectedGrade ?? '');
      await _prefs.setInt(_selectedClassKey, _selectedClass ?? 0);
      await _prefs.setString(_rememberedIdKey, _rememberedId ?? '');
      await _prefs.setString(_rememberedNameKey, _rememberedName ?? '');

      // ------------------------
    } else {
      await _prefs.remove(_rememberedEmailKey);
      await _prefs.remove(_rememberedPasswordKey);
      // --- 清除其他数据 ---
      await _prefs.remove(_selectedSchoolKey);
      await _prefs.remove(_selectedGradeKey);
      await _prefs.remove(_selectedClassKey);
      await _prefs.remove(_rememberedIdKey);
      await _prefs.remove(_rememberedNameKey);
      //-----------------------
    }
  }


  // 主要的登录处理方法 (显示验证码弹窗)
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
     setState(() {
        _loginError = null; // 清除之前的登录错误
      });
    _showCaptchaDialog(); // 显示验证码弹窗
  }

  // 显示验证码弹窗
  Future<void> _showCaptchaDialog() async {
     showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('验证'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('请输入验证码：'),
              const SizedBox(height: 16),
              SimpleCaptcha(
                isDialog: true, // 重要！
                onCompleted: (value) {
                  Navigator.of(context).pop(); // 关闭弹窗
                  _login(value); // 进行实际的登录
                },
                errorMessage: _captchaError, // 传递验证码错误
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _captchaError = null; // 取消时清除验证码错误
                });
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  // 实际的登录逻辑 (验证通过后调用)
  Future<void> _login(String captchaCode) async {
     setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user != null) {
          final userData = await _fetchUserData(res.user!.id);

        if (userData != null) {
          _selectedSchool = userData['school'] as String?;
          _selectedGrade = userData['grade'] as String?;
          _selectedClass = userData['class_number'] as int?;
          _rememberedId = userData['student_id'] as String?;
          _rememberedName = userData['name'] as String?;
          await _saveRememberMe();
        } else {
          _showErrorSnackBar("获取用户信息失败, 请联系管理员");
          setState(() {
            _isLoading = false;
          });
          return;
        }

        await _prefs.setString(_currentUserIdKey, res.user!.id);
        flg = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreenMain()),
        );

      } else {
         // 不再是通用错误，而是更具体的
        setState(() {
          _loginError = '邮箱或密码不正确，请检查后重试。'; // 设置 _loginError
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error during login: $e');
      // 根据不同的错误类型设置 _loginError
      setState(() {
         _isLoading = false;
        if (e is AuthException) {
          if (e.message.contains('Invalid login credentials')) {
            _loginError = '邮箱或密码不正确，请检查后重试。';
          } else if (e.message.contains('Email not confirmed')) { //示例：未验证邮箱
            _loginError = '您的邮箱尚未验证，请检查您的邮箱并点击验证链接。';
          }
           else {
              _loginError = '登录失败：${e.message}'; // 显示 Supabase 的错误消息
          }
        } else {
            _loginError = '登录时发生未知错误，请稍后重试。';
        }

      });
    } finally {
        if(mounted){ //防止pop之后继续setState
             setState(() => _isLoading = false);
        }
    }
  }

    Future<Map<String, dynamic>?> _fetchUserData(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('students')
          .select('school, class_name, student_id, name, auth_user_id') // 选择需要的列
          .eq('auth_user_id', userId)
          .single();

      if (response == null) {
        return null;
      }

      // 从 class_name 中提取年级和班级
      String className = response['class_name'] as String;
      String? grade;
      int? classNumber;

      // 提取年级.  这里假设年级是 "高一", "高二", "高三", "初一", "初二", "初三" 这样的格式
      final gradeMatch = RegExp(r'(高[一二三]|初[一二三])').firstMatch(className);
      if (gradeMatch != null) {
        grade = gradeMatch.group(0); // 获取匹配到的年级
      }

      // 提取班级号. 这里假设班级号是数字.
      final classMatch = RegExp(r'(\d+)').firstMatch(className);
      if (classMatch != null) {
        classNumber = int.tryParse(classMatch.group(0)!); //转换为 int
      }

      return {
        'school': response['school'] as String, // 直接使用原始的 school 值
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
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
                     if (_loginError != null) ...[ // 显示登录错误
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
                              if (!_rememberMe) {
                                _autoLogin = false;
                              }
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
                              if (_autoLogin) {
                                _rememberMe = true;
                              }
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
                      onPressed: _isLoading
                          ? null
                          : _handleLogin, // 点击登录按钮，显示验证码弹窗
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