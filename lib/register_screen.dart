import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'school_data.dart';
import 'login_screen.dart'; // 确保引入 LoginScreen

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key});

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
        _selectedClassName = '$_selectedGrade$_selectedClass班';
      });
    } else {
      setState(() {
        _selectedClassName = null;
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final studentId = _studentIdController.text.trim();
      final name = _nameController.text.trim();
      final password = _passwordController.text;
      final school = _selectedSchool!;
      final className = _selectedClassName!;

      // 1. 使用 Supabase Auth 创建用户
      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: email, // 使用用户提供的邮件地址
        password: password,
        data: {
          'name': name,
          'student_id': studentId,
          'class_name': className,
          'school': school,
        },
      );

      // 2. 注册成功后，将用户信息添加到 "students" 表中
      if (res.user != null) {
        await _createStudentProfile(
          userId: res.user!.id,
          studentId: studentId,
          name: name,
          className: className,
          school: school,
        );

        _showSuccessSnackBar('注册成功，请登录');
        Navigator.pushReplacement( // 使用 pushReplacement
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()), // 导航到 LoginScreen
        );
      } else {
        _showErrorSnackBar('注册失败，请重试');
      }
    } on AuthException catch (error) {
      // 处理 Supabase Auth 错误
      _showErrorSnackBar('注册失败: ${error.message}');
    } catch (e) {
      String errorMessage = '注册失败，请重试';
      if (e is PostgrestException) {
        if (e.code == '23505') {
          errorMessage = '该用户已注册';
        } else {
          errorMessage = '数据库错误，请稍后重试';
        }
      } else {
        print('Error during registration: $e');
      }
      _showErrorSnackBar(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
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
      await Supabase.instance.client.from('students').insert({
        'auth_user_id': userId, //  使用 auth_user_id
        'student_id': studentId,
        'name': name,
        'class_name': className,
        'school': school,
      });
    } catch (e) {
      print('Error creating student profile: $e');
      throw e; //  重新抛出异常，以便在 _handleRegister 中处理
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
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
                        Navigator.push(context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen()),);
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