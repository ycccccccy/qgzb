import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'school_data.dart';
import 'login_screen.dart';
import 'simple_captcha.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController(); 
  final TextEditingController _studentIdController = TextEditingController(); 
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;
  bool _canRegister = true; // 控制是否可以注册
  String? _selectedGrade;
  int? _selectedClass;
  String? _selectedClassName;
  String? _selectedDistrict;
  String? _selectedSchool;
  String? _captchaError;

  @override
  void dispose() {
    _emailController.dispose();
    _studentIdController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateClassValue() {
    if (_selectedGrade != null && _selectedClass != null) {
      setState(() {
        _selectedClassName = '$_selectedGrade${_selectedClass}班';
      });
    } else {
      setState(() {
        _selectedClassName = null;
      });
    }
  }
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate() || !_canRegister) {
      return;
    }

    setState(() {
      _isLoading = true;
      _canRegister = false; // 禁用注册按钮
    });

    final email = _emailController.text.trim();
    final studentId = _studentIdController.text.trim();
    final name = _nameController.text.trim();
    final school = _selectedSchool!;
    final className = _selectedClassName!;
    final password = _passwordController.text;

    // 检查是否已存在同名、同校、同班的用户
    try {
      final duplicateCheck = await Supabase.instance.client
          .from('students')
          .select('name')
          .eq('name', name)
          .eq('school', school)
          .eq('class_name', className)
          .limit(1);

      if (duplicateCheck.isNotEmpty) {
        if (mounted) {
          _showErrorSnackBar('已存在相同用户，请勿重复注册');
        }
        _resetRegisterState(); // 重置注册状态
        return;
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('查询出错：$e');
      }
      _resetRegisterState();
      return;
    }

    // 获取 NavigatorState
    final navigator = Navigator.of(context);

    // 显示人机验证对话框
    showDialog(
      context: context, // 使用 context
      barrierDismissible: false,
      builder: (BuildContext dialogContext) { // 使用 dialogContext
        return AlertDialog(
          title: const Text('人机验证'),
          content: SimpleCaptcha(
            isDialog: true,
            errorMessage: _captchaError,
            onCompleted: (captcha) async {
              if (captcha.isEmpty) {
                setState(() {
                  _captchaError = "验证码错误";
                });
                return;
              }

              navigator.pop(); // 使用 navigator
              setState(() {
                _captchaError = null;
              });

              // 人机验证通过，立即显示邮箱验证对话框
              if (mounted) {
                _showEmailVerificationDialog(
                  context, // 使用 context
                  email,
                  studentId,
                  name,
                  school,
                  className,
                  password,
                );
              }
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                navigator.pop(); // 使用 navigator
                _resetRegisterState();
              },
            ),
          ],
        );
      },
    );
  }

// 重置注册状态 (允许再次注册)
  void _resetRegisterState() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _canRegister = true; // 启用注册按钮
      });
    }
  }

  // 发送邮箱验证码
  Future<void> _sendVerificationCode(String email) async {
    try {
      await Supabase.instance.client.auth.signInWithOtp(email: email);
      // 邮件发送成功，不需要在这里显示提示，因为对话框已经显示
    } catch (e) {
      if (mounted) _showErrorSnackBar('发送验证码失败：$e');
    }
  }

  // 显示邮箱验证对话框
  void _showEmailVerificationDialog(
    BuildContext context,
    String email,
    String studentId,
    String name,
    String school,
    String className,
    String password,
  ) {
    final TextEditingController verificationCodeController =
        TextEditingController();
    bool shouldNavigate = false;

    // 立即发送验证码
    _sendVerificationCode(email);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('邮箱验证'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('请输入发送到你邮箱的验证码'),
              const SizedBox(height: 16),
              TextField(
                controller: verificationCodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '验证码',
                  hintText: '请输入验证码',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _resetRegisterState();
              },
            ),
            TextButton(
              child: const Text('验证'),
              onPressed: () async {
                final code = verificationCodeController.text.trim();
                if (code.isEmpty) {
                  if (mounted) _showErrorSnackBar('请输入验证码');
                  return;
                }

                try {
                  // 使用 verifyOTP 验证邮箱验证码
                  final res = await Supabase.instance.client.auth.verifyOTP(
                    email: email,
                    token: code,
                    type: OtpType.email,
                  );

                  if (res.user != null) {
                    // 验证码验证成功，注册用户
                    final AuthResponse res2 =
                        await Supabase.instance.client.auth.signUp(
                      email: email,
                      password: password,
                      data: {
                        'name': name,
                        'student_id': studentId,
                        'class_name': className,
                        'school': school,
                      },
                    );

                    if (res2.user == null) {
                      if (mounted) {
                        _showErrorSnackBar('注册失败，请重试');
                      }
                      _resetRegisterState();
                      return;
                    }

                    // 插入 students 表
                    await _createStudentProfile(
                      userId: res2.user!.id,
                      studentId: studentId,
                      name: name,
                      className: className,
                      school: school,
                    );

                    shouldNavigate = true;
                    if (mounted) _showSuccessSnackBar('注册成功！');
                  } else {
                    if (mounted) _showErrorSnackBar('验证码错误');
                  }
                } catch (e) {
                  if (mounted) _showErrorSnackBar('验证失败：$e');
                } finally {
                  Navigator.of(dialogContext).pop(); // 确保对话框关闭
                  _resetRegisterState(); // 重置注册状态
                }
              },
            ),
          ],
        );
      },
    ).then((_) {
      if (shouldNavigate) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    });
  }

  Future<void> _createStudentProfile({
    required String userId,
    required String studentId,
    required String name,
    required String className,
    required String school,
  }) async {
    try {
      await Supabase.instance.client.from('students').insert({
        'auth_user_id': userId,
        'student_id': studentId,
        'name': name,
        'class_name': className,
        'school': school,
      });
    } catch (e) {
      rethrow;
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

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
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
                      '注册',
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
                        // 更严格的邮箱格式验证
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
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
                        // 可以添加更多学号验证规则
                        return null;
                      },
                    ),
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
                        // 可以添加更多姓名验证规则
                        return null;
                      },
                    ),
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
                          _selectedClass = null;
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
                          _selectedClass = null;
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
                        // 可以添加更多密码验证规则 (例如，强度验证)
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('注册',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      },
                      child: const Text('已有账号？去登录。',
                          style: TextStyle(color: Colors.blueGrey)),
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