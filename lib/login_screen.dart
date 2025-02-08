import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen_main.dart'; // 假设的主页
import 'register_screen.dart'; // 假设的注册页面
import 'package:flutter/services.dart';
import 'school_data.dart'; //假设的, 如果你不需要注册功能, 这个可以删掉.

// 定义 SharedPreferences 的 Key 常量
const String _rememberMeKey = 'rememberMe';
const String _autoLoginKey = 'autoLogin';
const String _rememberedEmailKey = 'rememberedEmail';
const String _rememberedPasswordKey = 'rememberedPassword';
const String _currentUserIdKey = 'current_user_id';
const String _selectedSchoolKey = 'selectedSchool';      //保留
const String _selectedGradeKey = 'selectedGrade';        //保留
const String _selectedClassKey = 'selectedClass';        //保留
const String _rememberedIdKey = 'rememberedId';          //保留
const String _rememberedNameKey = 'rememberedName';       //保留

// 忘记密码的联系方式(保持不变)
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

  late final SharedPreferences _prefs;

  // ---  用于在登录后存储其他信息 ---
  String? _selectedSchool;
  String? _selectedGrade;
  int? _selectedClass;
  String? _rememberedId;
  String? _rememberedName;
  // --------------------------------------
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

      // --- 加载其他的存储数据 ---
      _selectedSchool = _prefs.getString(_selectedSchoolKey);
      _selectedGrade = _prefs.getString(_selectedGradeKey);
      _selectedClass = _prefs.getInt(_selectedClassKey);
      _rememberedId = _prefs.getString(_rememberedIdKey);
      _rememberedName = _prefs.getString(_rememberedNameKey);
      // --------------------------------
    }
    // --- 自动登录逻辑 ---
    if (_autoLogin && !flg) {
      //直接尝试登录
      _handleLogin();
    }
    // ---------------------
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // 使用 Supabase Auth 登录
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user != null) {
        // --- 从数据库获取并保存其他信息 ---
        final userData = await _fetchUserData(res.user!.id);

        if (userData != null) {
          _selectedSchool = userData['school'] as String?;
          _selectedGrade = userData['grade'] as String?;
          _selectedClass = userData['class_number'] as int?; //假设数据库字段是 class_number
          _rememberedId = userData['student_id'] as String?;
          _rememberedName = userData['name'] as String?;

          // 保存到 SharedPreferences
          await _saveRememberMe();

          // --- 打印所有存储在本地的信息 ---
          //print('--------- Local Storage Data ---------');
          //print('Remember Me: ${_prefs.getBool(_rememberMeKey)}');
          //print('Auto Login: ${_prefs.getBool(_autoLoginKey)}');
          //print('Email: ${_prefs.getString(_rememberedEmailKey)}');
          //print('Password: ${_prefs.getString(_rememberedPasswordKey)}');
          //print('User ID: ${_prefs.getString(_currentUserIdKey)}');
          //print('School: ${_prefs.getString(_selectedSchoolKey)}');
          //print('Grade: ${_prefs.getString(_selectedGradeKey)}');
          //print('Class: ${_prefs.getInt(_selectedClassKey)}');
          //print('Student ID: ${_prefs.getString(_rememberedIdKey)}');
          //print('Name: ${_prefs.getString(_rememberedNameKey)}');
          //print('--------------------------------------');
          // ----------------------------------

        } else {
          //如果获取信息失败
          _showErrorSnackBar("获取用户信息失败, 请联系管理员");
          setState(() {
            _isLoading = false;
          });
          return;
        }
        // --------------------------------------
        await _prefs.setString(_currentUserIdKey, res.user!.id); // 保存 auth_user_id

        // ---  设置 flg 为 true ---
        flg = true;
        // --------------------------
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreenMain()),
        );
      } else {
        _showErrorSnackBar('邮箱或密码错误');
      }
    } catch (e) {
      print('Error during login: $e'); // 打印详细错误信息
      _showErrorSnackBar('登录失败，请重试。');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 从数据库获取用户的其他信息
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