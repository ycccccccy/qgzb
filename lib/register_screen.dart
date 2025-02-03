import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'login_screen.dart';
import 'package:flutter/services.dart';
import 'school_data.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
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
      final studentId = _studentIdController.text.trim();
      final name = _nameController.text.trim();
      final password = _passwordController.text;
      final school = _selectedSchool;


      final isSuccess = await _registerStudent(
        studentId: studentId,
        name: name,
        className: _selectedClassName!,
        password: password,
        school: school ?? '',
      );
      if (isSuccess) {
        _showSuccessSnackBar('注册成功，请登录');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        _showErrorSnackBar('注册失败，请重试');
      }
    } catch (e) {
       String errorMessage = '注册失败，请重试';
        if (e is PostgrestException) {
           if(e.code == '23505'){
             errorMessage = '该用户已注册';
           }else{
             errorMessage = '数据库错误，请稍后重试';
           }
         }else{
            print('Error during registration: $e');
         }
      _showErrorSnackBar(errorMessage);
    } finally {
      setState(() => _isLoading = false);
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
                        items: schoolList.keys.map((district) => DropdownMenuItem(
                            value: district,
                            child: Text(district),
                            )).toList(),
                       onChanged: (value) {
                        setState(() {
                          _selectedDistrict = value;
                          _selectedSchool = null;
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
                            ? schoolList[_selectedDistrict]?.map((school) => DropdownMenuItem(
                            value: school,
                            child: Text(school),
                         )).toList()
                            : [],
                       onChanged: (value) {
                        setState(() {
                          _selectedSchool = value;
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
                              _selectedGrade = value;
                               _updateClassValue();
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
                              _selectedClass = value;
                             _updateClassValue();
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
                        Navigator.pop(context);
                      },
                      child: const Text('已有账号？去登录',style: TextStyle(color: Colors.blueGrey),),
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
   String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  String _generateHash(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

   Future<bool> _registerStudent({
    required String studentId,
    required String name,
    required String className,
    required String password,
    required String school
  }) async {
    final salt = _generateSalt();
    final passwordHash = _generateHash(password, salt);
    try {
      await Supabase.instance.client
          .from('students')
          .insert({
        'student_id': studentId,
        'name': name,
        'class_name': className,
        'password_hash': passwordHash,
        'salt': salt,
        'school': school,
      });
      return true;
    } catch (e) {
      print('Error during registration: $e');
      return false;
    }
  }

}