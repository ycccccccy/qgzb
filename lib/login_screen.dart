import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen_main.dart'; // 假设的主页
import 'simple_captcha.dart'; // 假设的验证码组件
import 'register_screen.dart'; // 假设的注册页面
import 'package:flutter/services.dart';
import 'school_data.dart';  //假设的

// 定义 SharedPreferences 的 Key 常量
const String _rememberMeKey = 'rememberMe';
const String _autoLoginKey = 'autoLogin';
const String _rememberedIdKey = 'rememberedId';
const String _rememberedNameKey = 'rememberedName';
const String _rememberedPasswordKey = 'rememberedPassword';
const String _currentUserIdKey = 'current_user_id'; // 用于存储 auth_user_id
const String _selectedDistrictKey = 'selectedDistrict';
const String _selectedSchoolKey = 'selectedSchool';
const String _selectedGradeKey = 'selectedGrade';
const String _selectedClassKey = 'selectedClass';
const String _rememberedEmailKey = 'rememberedEmail'; //  新增存储 email 的 key

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
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController =
      TextEditingController(); //  新增 email controller
  bool _passwordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _autoLogin = false;
  String? _selectedGrade;
  int? _selectedClass;
  String? _selectedClassName;
  String? _selectedDistrict;
  String? _selectedSchool;

  late final SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadSharedPreferences();
  }

    Future<void> _loadSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadRememberMe();
    _attemptAutoLogin();
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _emailController.dispose(); // 释放 email controller
    super.dispose();
  }

  void _updateClassValue() {
    if (_selectedGrade != null && _selectedClass != null) {
      setState(() {
        _selectedClassName = '$_selectedGrade$_selectedClass班';
      });
    } else {
      setState(() {
        _selectedClassName = null;
      });
    }
  }

  Future<void> _loadRememberMe() async {
    setState(() {
      _rememberMe = _prefs.getBool(_rememberMeKey) ?? false;
      _autoLogin = _prefs.getBool(_autoLoginKey) ?? false;
      if (_rememberMe || _autoLogin) {
        _studentIdController.text = _prefs.getString(_rememberedIdKey) ?? '';
        _nameController.text = _prefs.getString(_rememberedNameKey) ?? '';
        _emailController.text =
            _prefs.getString(_rememberedEmailKey) ?? ''; // 读取 email
        if (_autoLogin) {
          _passwordController.text =
              _prefs.getString(_rememberedPasswordKey) ?? '';
        }
      }
      _selectedDistrict = _prefs.getString(_selectedDistrictKey);
      _selectedSchool = _prefs.getString(_selectedSchoolKey);
      _selectedGrade = _prefs.getString(_selectedGradeKey);
      _selectedClass = _prefs.getInt(_selectedClassKey);
      _updateClassValue();
    });
  }

  Future<void> _saveRememberMe() async {
    await _prefs.setBool(_rememberMeKey, _rememberMe);
    await _prefs.setBool(_autoLoginKey, _autoLogin);
    if (_rememberMe || _autoLogin) {
      await _prefs.setString(_rememberedIdKey, _studentIdController.text);
      await _prefs.setString(_rememberedNameKey, _nameController.text);
      await _prefs.setString(_rememberedEmailKey, _emailController.text); // 存储 email
      if (_autoLogin) {
        await _prefs.setString(_rememberedPasswordKey, _passwordController.text);
      } else {
        await _prefs.remove(_rememberedPasswordKey);
      }
      await _prefs.setString(_selectedDistrictKey, _selectedDistrict ?? '');
      await _prefs.setString(_selectedSchoolKey, _selectedSchool ?? '');
      await _prefs.setString(_selectedGradeKey, _selectedGrade ?? '');
      await _prefs.setInt(_selectedClassKey, _selectedClass ?? 0);
    } else {
      await _prefs.remove(_rememberedIdKey);
      await _prefs.remove(_rememberedNameKey);
      await _prefs.remove(_rememberedPasswordKey);
      await _prefs.remove(_selectedDistrictKey);
      await _prefs.remove(_selectedSchoolKey);
      await _prefs.remove(_selectedGradeKey);
      await _prefs.remove(_selectedClassKey);
      await _prefs.remove(_rememberedEmailKey); //  移除 email
    }
  }

  void _onCaptchaCompleted(String value) {}

  Future<(String?, String?, String?, String?, String?, int?)>
      _loadAutoLoginInfo() async {
    final rememberedId = _prefs.getString(_rememberedIdKey);
    final rememberedName = _prefs.getString(_rememberedNameKey);
    final rememberedPassword = _prefs.getString(_rememberedPasswordKey);
    final selectedDistrict = _prefs.getString(_selectedDistrictKey);
    final selectedSchool = _prefs.getString(_selectedSchoolKey);
    final selectedClass = _prefs.getInt(_selectedClassKey);
    return (rememberedId, rememberedName, rememberedPassword, selectedDistrict,
        selectedSchool, selectedClass);
  }

  Future<void> _attemptAutoLogin() async {
    final autoLogin = _prefs.getBool(_autoLoginKey) ?? false;

    final (rememberedId, rememberedName, rememberedPassword, selectedDistrict,
            selectedSchool, selectedClass) =
        await _loadAutoLoginInfo();
    if (autoLogin &&
        rememberedId != null &&
        rememberedName != null &&
        rememberedPassword != null &&
        selectedDistrict != null &&
        selectedSchool != null &&
        selectedClass != null &&
        !flg) {
      setState(() => _isLoading = true);
      try {
        final isValid = await _verifyStudent(
          studentId: rememberedId,
          name: rememberedName,
          className: '$_selectedGrade$_selectedClass班',
          password: rememberedPassword,
          school: selectedSchool ?? '',
        );
        if (isValid) {
          // await _prefs.setString(_currentUserIdKey, rememberedId); // 不再需要
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreenMain()));
        } else {
          setState(() => _isLoading = false);
          _showErrorSnackBar('自动登录失败，请重试');
        }
      } catch (e) {
        setState(() => _isLoading = false);
        print('Error during auto login: $e');
        _showErrorSnackBar('自动登录失败，请重试');
      }
    }
    if (flg) {
      flg = false;
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await _showCaptchaDialog();
      if (result == null) {
        setState(() => _isLoading = false);
        return;
      }
      final studentId = _studentIdController.text.trim();
      final name = _nameController.text.trim();
      final password = _passwordController.text;
      final school = _selectedSchool;

      final isValid = await _verifyStudent(
        studentId: studentId,
        name: name,
        className: _selectedClassName!,
        password: password,
        school: school ?? '',
      );
      if (isValid) {
        await _saveRememberMe();
        // await _prefs.setString(_currentUserIdKey, studentId); // 不再需要存学号
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreenMain()));
      } else {
        _showErrorSnackBar('学号/姓名/班级或密码或学校错误');
      }
    } catch (e) {
      String errorMessage = '登录失败，请重试';
      if (e is PostgrestException) {
        if (e.code == '23505') {
          errorMessage = '该用户不存在';
        } else {
          errorMessage = '数据库错误，请稍后重试';
        }
      } else {
        print('Error during login: $e');
      }
      _showErrorSnackBar(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _showCaptchaDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[50],
          title: const Text('验证码验证',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: SimpleCaptcha(
            onCompleted: (value) {
              Navigator.of(context).pop(value);
            },
            isDialog: true,
          ),
        );
      },
    );
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 20 : 40),
          child: Card(
            elevation: 4,
            color: Colors.grey[50],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 20 : 40),
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
                    buildTextFormField(
                      controller: _emailController,
                      labelText: '邮箱',
                      hintText: '请输入你的邮箱',
                      prefixIcon: Icons.email,
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
                    buildTextFormField(
                        controller: _studentIdController,
                        labelText: '学号',
                        hintText: '请输入你的学号',
                        prefixIcon: Icons.school,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '学号不能为空';
                          }
                          return null;
                        }),
                    const SizedBox(height: 16),
                    buildTextFormField(
                        controller: _nameController,
                        labelText: '姓名',
                        hintText: '请输入你的姓名',
                        prefixIcon: Icons.person,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '姓名不能为空';
                          }
                          return null;
                        }),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: '区',
                        hintText: '请选择区',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      value: _selectedDistrict,
                      items: schoolList.keys
                          .map((district) => DropdownMenuItem(
                                value: district,
                                child: Text(district),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDistrict = value;
                          _selectedSchool = null;
                          _selectedGrade = null;
                          _updateClassValue();
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请选择区';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: '学校',
                        hintText: '请选择学校',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      value: _selectedSchool,
                      items: _selectedDistrict != null
                          ? schoolList[_selectedDistrict]
                              ?.map((school) => DropdownMenuItem(
                                    value: school,
                                    child: Text(school),
                                  ))
                              .toList()
                          : [],
                      onChanged: (value) {
                        setState(() {
                          _selectedSchool = value;
                          _selectedGrade = null;
                          _updateClassValue();
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请选择学校';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: '年级',
                              hintText: '请选择年级',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            value: _selectedGrade,
                            items: [
                              '初一',
                              '初二',
                              '初三',
                              '高一',
                              '高二',
                              '高三',
                            ]
                                .map((grade) => DropdownMenuItem(
                                      value: grade,
                                      child: Text(grade),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedGrade = value;
                                _selectedClass = null;
                                _updateClassValue();
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请选择年级';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            decoration: InputDecoration(
                              labelText: '班级',
                              hintText: '请选择班级',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            value: _selectedClass,
                            items: List.generate(50, (index) => index + 1)
                                .map((classNum) => DropdownMenuItem(
                                      value: classNum,
                                      child: Text('$classNum班'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedClass = value;
                                _updateClassValue();
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return '请选择班级';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildTextFormField(
                        controller: _passwordController,
                        labelText: '密码',
                        hintText: '请输入你的密码',
                        prefixIcon: Icons.lock,
                        obscureText: !_passwordVisible,
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '密码不能为空';
                          }
                          if (value.length < 6) {
                            return '密码长度至少为6位';
                          }
                          return null;
                        }),
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

  TextFormField buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    IconButton? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }

    Future<bool> _verifyStudent({
    required String studentId,
    required String name,
    required String className,
    required String password,
    required String school,
  }) async {
    try {
      final studentData =
          await _fetchStudentData(studentId, name, school, className: className);
      if (studentData == null) {
        return false;
      }
      final email = _emailController.text.trim(); // 获取用户输入的邮箱
      // 使用 Supabase Auth 登录
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email, // 使用邮箱登录
        password: password,
      );
      //final userId = res.user?.id;
      // 重点：登录成功后，保存 auth_user_id
      if (res.user != null) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(_currentUserIdKey, res.user!.id); // 保存 auth_user_id
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error during verifyStudent: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _fetchStudentData(
      String studentId, String name, String school,
      {String? className}) async {
    final query = Supabase.instance.client
        .from('students')
        .select()
        .eq('student_id', studentId)
        .eq('name', name)
        .eq('school', school);
    if (className != null) {
      query.eq('class_name', className);
    }
    final response = await query;
    if (response.isEmpty) {
      return null;
    }
    return response[0];
  }
}