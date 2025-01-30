import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'dart:math';
import 'simple_captcha.dart'; 

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
    late String _captchaCode; 
  bool _passwordVisible = false;
  bool _isLoading = false;

    @override
  void dispose() {
    _studentIdController.dispose();
    _nameController.dispose();
    _classController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  void _onCaptchaCompleted(String value) {
     _captchaCode = value;
  }


  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
       setState(() => _isLoading = true);
        try {
        final result = await _showCaptchaDialog();
       if(result == null){
             setState(() => _isLoading = false);
            return;
        }
           final studentId = _studentIdController.text.trim();
         final name = _nameController.text.trim();
         final className = _classController.text;
         final password = _passwordController.text;

       final isValid = await _verifyStudent(
        studentId: studentId,
        name: name,
        className: className,
        password: password,
      );


      if (isValid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_id', studentId);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('学号/姓名/班级或密码错误')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('登录/注册失败，请重试')));
      print('Error during login/registration: $e');
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
                title: Text('验证码验证', textAlign: TextAlign.center,  style: TextStyle(color: Colors.black87)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                content: SimpleCaptcha(
                     onCompleted: (value){
                       Navigator.of(context).pop(value);
                     },
                     isDialog: true,
                   ),
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
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                    padding: EdgeInsets.all(isMobile ? 20 : 40),
                     child: Form(
                      key: _formKey,
                      child: Column(
                           mainAxisSize: MainAxisSize.min,
                           crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                           Text(
                              '欢迎使用',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                           textAlign: TextAlign.center,
                           ),
                          SizedBox(height: 20),
                            TextFormField(
                              controller: _studentIdController,
                              decoration: InputDecoration(
                                  labelText: '学号',
                                  hintText: '请输入你的学号',
                                  prefixIcon: Icon(Icons.school),
                                filled: true,
                                fillColor: Colors.white,
                                 border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                     borderSide: BorderSide.none,
                                ),
                                  ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '学号不能为空';
                                }
                                return null;
                              },
                            ),
                              SizedBox(height: 16),
                             TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                   labelText: '姓名',
                                   hintText: '请输入你的姓名',
                                     prefixIcon: Icon(Icons.person),
                                  filled: true,
                                  fillColor: Colors.white,
                                border: OutlineInputBorder(
                                     borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                   ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '姓名不能为空';
                                }
                                return null;
                              },
                            ),
                             SizedBox(height: 16),
                             TextFormField(
                                controller: _classController,
                                decoration: InputDecoration(
                                 labelText: '班级',
                                 hintText: '请输入你的班级',
                                  prefixIcon: Icon(Icons.class_),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                     borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                ),
                             ),
                               validator: (value) {
                                 if (value == null || value.isEmpty) {
                                 return '班级不能为空';
                                 }
                                 return null;
                               },
                           ),
                               SizedBox(height: 16),
                             TextFormField(
                              controller: _passwordController,
                              obscureText: !_passwordVisible,
                              decoration: InputDecoration(
                                labelText: '密码',
                                hintText: '请输入你的密码',
                                 prefixIcon: Icon(Icons.lock),
                                  filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                     borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                ),
                                  suffixIcon: IconButton(
                                    icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                                    onPressed: () {
                                      setState(() {
                                        _passwordVisible = !_passwordVisible;
                                      });
                                    },
                                  ),
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
                             SizedBox(height: 24),
                            ElevatedButton(
                                 onPressed: _isLoading ? null : _handleLogin,
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: Colors.blue,
                                   padding: EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: _isLoading
                                    ? CircularProgressIndicator(color: Colors.white)
                                    : Text('登录/注册',
                                 style: TextStyle(fontSize: 18, color: Colors.white)),
                           ),
                        ]
                    )
               ),
              ),
            ),
          ),
      )
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


    Future<bool> _verifyStudent({
    required String studentId,
    required String name,
    required String className,
    required String password,
  }) async {
    try {
      final studentData = await _fetchStudentData(studentId, name);

       if(studentData == null){
         return false;
       }


        if (studentData['password_hash'] == null || studentData['password_hash'] == '') {
            return await _handleFirstLogin(studentId, password, className);
        } else {
            return _handleNormalLogin(password, studentData);
        }
    } catch (e) {
       print('Error during verifyStudent: $e');
      return false;
    }
  }

    Future<Map<String, dynamic>?> _fetchStudentData(String studentId, String name) async {
     final query = Supabase.instance.client
            .from('students')
            .select()
            .eq('student_id', studentId)
            .eq('name', name);
         final response = await query;
       if(response.isEmpty){
           return null;
        }
    return response[0];
    }

  Future<bool> _handleFirstLogin(String studentId, String password, String className) async {
      final salt = _generateSalt();
      final passwordHash = _generateHash(password, salt);
    try {
      await Supabase.instance.client
          .from('students')
          .update({
        'password_hash': passwordHash,
        'salt': salt,
        'class_name':className,
      })
          .eq('student_id', studentId);
       return true;
    } catch (e) {
      print('Error during first login/registration: $e');
       return false;
    }
  }

  Future<bool> _handleNormalLogin(String password, Map<String, dynamic> studentData) async {
    final storedHash = studentData['password_hash'];
    final salt = studentData['salt'];
    final inputHash = _generateHash(password, salt);
    return inputHash == storedHash;
  }
}