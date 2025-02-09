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

  // 根据年级和班级更新班级名称
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

  // 发送邮箱验证码
  Future<void> _sendVerificationCode(String email) async {
    try {
      await Supabase.instance.client.auth.signInWithOtp(email: email);
      if (mounted) _showSuccessSnackBar('验证码已发送，请查收');
    } catch (e) {
      if (mounted) _showErrorSnackBar('发送验证码失败：$e');
    }
  }

  // 处理注册逻辑
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final studentId = _studentIdController.text.trim();
    final name = _nameController.text.trim();
    final school = _selectedSchool!;
    final className = _selectedClassName!;

    // 检查是否已存在同名、同校、同班的用户
    try {
      final duplicateCheck = await Supabase.instance.client
          .from('public_students')
          .select('name') // Select a non-null column
          .eq('name', name)
          .eq('school', school)
          .eq('class_name', className)
          .limit(1);

      if (duplicateCheck.isNotEmpty) {
        if (mounted) {
          _showErrorSnackBar('已存在相同用户，请勿重复注册');
          setState(() => _isLoading = false);
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('查询出错：$e');
        setState(() => _isLoading = false);
      }
      return;
    }

    // 显示人机验证对话框
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('你真的是人类吗？'),
          content: SimpleCaptcha(
            isDialog: true,
            errorMessage: _captchaError,
            onCompleted: (captcha) async {
              // 人机验证通过
              setState(() {
                _captchaError = null; // Clear any previous error
              });

              Navigator.of(context).pop(); // Close the captcha dialog

              _sendVerificationCode(email); // Send verification code

              if (mounted) {
                _showEmailVerificationDialog(
                    context, email); // Show email verification dialog
              }
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                if (mounted) setState(() => _isLoading = false);
              },
            ),
          ],
        );
      },
    );
  }

  // 显示邮箱验证对话框
  void _showEmailVerificationDialog(BuildContext context, String email) {
    final TextEditingController verificationCodeController =
        TextEditingController();
    bool shouldNavigate = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
                Navigator.of(context).pop();
                if (mounted) setState(() => _isLoading = false);
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
                  final res = await Supabase.instance.client.auth
                      .verifyOTP(
                        email: email,
                        token: code,
                        type: OtpType.email,
                      )
                      .timeout(Duration(seconds: 30));

                  if (res.user != null) {
                    Navigator.of(context).pop();

                    final studentId = _studentIdController.text.trim();
                    final name = _nameController.text.trim();
                    final password = _passwordController.text;
                    final school = _selectedSchool!;
                    final className = _selectedClassName!;

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
                    ).timeout(Duration(seconds: 30));

                    if (res2.user != null) {
                      await _createStudentProfile(
                        userId: res2.user!.id,
                        studentId: studentId,
                        name: name,
                        className: className,
                        school: school,
                      );

                      // 调试输出
                      shouldNavigate = true;

                      if (mounted) {
                        _showSuccessSnackBar('注册成功！请前往登录页面以登录');
                      }
                    } else {
                      if (mounted) _showErrorSnackBar('注册失败，请重试');
                    }
                  } else {
                    if (mounted) _showErrorSnackBar('验证失败，请检查验证码');
                  }
                } catch (e) {
                  if (mounted) {
                    _showErrorSnackBar('注册失败：$e');
                    setState(() => _isLoading = false);
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
            ),
          ],
        );
      },
    ).then((_) {
      // 调试输出
      // 检查 mounted 的 值
      if (mounted) {
        setState(() {});
      }
      if (shouldNavigate && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context, // 明确使用 context
            MaterialPageRoute(
              builder: (context) => LoginScreen(
              ),
            ),
          );
        });
      }
    });
  }

  // 创建学生信息
  Future<void> _createStudentProfile({
    required String userId,
    required String studentId,
    required String name,
    required String className,
    required String school,
  }) async {
    try {
      final insertResult =
          await Supabase.instance.client.from('students').insert({
        'auth_user_id': null, // Set to null initially
        'student_id': studentId,
        'name': name,
        'class_name': className,
        'school': school,
      }).select('id');

      if (insertResult.isEmpty) {
        throw Exception('Failed to insert student record and get ID.');
      }
      final studentRecordId = insertResult[0]['id'];

      // Update auth_user_id immediately
      await Supabase.instance.client.from('students').update({
        'auth_user_id': userId,
      }).eq('id', studentRecordId);
    } catch (e) {
      throw e;
    }
  }

  // 显示错误消息
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

  // 显示成功消息
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
                          style:
                              TextStyle(fontSize: 18, color: Colors.white)),
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
}