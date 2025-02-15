import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hyxj/api_service.dart'; 
import 'package:hyxj/home_screen_main.dart'; 
import 'package:hyxj/register_screen.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
  final _apiService = ApiService();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  late AnimationController _controller;
  late Animation<double> _cardScaleAnimation;
  late Animation<Offset> _cardSlideAnimation; // 卡片滑动动画

  @override
  void initState() {
    super.initState();
    _loadRememberedData();
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));

    

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // 动画时间
    );

    _cardScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut, // 使用更平滑的曲线
      ),
    );

    // 卡片从下方滑入
    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3), // 从下方30%的位置开始
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut, // 使用缓出效果
      ),
    );

    _controller.forward();
  }

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
      if (_emailController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty) {
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
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _controller.dispose();
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

      final loginResult = await _apiService.login(email, password);

      final userId = loginResult['userId'];
      await _prefs.setString(_currentUserIdKey, userId.toString());

      final userData = await _fetchUserData(userId.toString());
      if (userData != null) {
        _selectedSchool = userData['school'] as String?;
        _selectedGrade = userData['grade'] as String?;
        _selectedClass = userData['class_number'] as int?;
        _rememberedId = userData['student_id'] as String?;
        _rememberedName = userData['name'] as String?;
        _salt = userData['salt'] as String?;
        _password = userData['password'] as String?;

        if (_rememberMe) {
          await _saveRememberMe();
        }
        if (_autoLogin) {
          await _prefs.setBool(_autoLoginKey, true);
        }

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
      if (mounted) {
        setState(() {
          _loginError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchUserData(String userId) async {
    try {
      final user = await _apiService.getUserInfo(int.parse(userId));

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
          title: const Text('忘记密码？', style: TextStyle(color: Color(0xFF34495E))), // 深灰蓝标题
          content: const Text(_contactInfo, style: TextStyle(color: Color(0xFF4A6572))), // 灰蓝色内容
          backgroundColor: const Color(0xFFF5F7FA), // 更柔和的背景色
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // 圆角
          actions: <Widget>[
            TextButton(
              child: const Text('关闭', style: TextStyle(color: Color(0xFF3498DB))), // 品牌蓝色
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
    final maxWidth = screenWidth > 600 ? 500.0 : double.infinity;
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFF90CAF9), //  ✅  全局设置导航栏透明
      systemNavigationBarIconBrightness: Brightness.light, //  ✅  全局设置导航栏图标颜色
    ));

    return Scaffold(
      body: Container(
        
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFC5E1F5), // 轻柔的天蓝色
              Color(0xFF90CAF9), // 柔和的浅蓝色
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _cardScaleAnimation.value,
                  child: SlideTransition( // 使用 SlideTransition
                    position: _cardSlideAnimation,
                    child: child,
                  ),
                );
              },
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Card(
                  elevation: 10, // 增加阴影深度
                  shadowColor: Colors.black26, // 更柔和的阴影颜色
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28), // 更圆润的边角
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 标题部分
                          const SizedBox(height: 32),
                          Text(
                            '欢迎登录',
                            style: TextStyle(
                              fontSize: 36, // 更大的字体
                              fontWeight: FontWeight.w700, // 更粗的字体
                              color: const Color(0xFF34495E), // 深灰蓝色，更沉稳
                              letterSpacing: 1.5, // 字母间距更宽
                              fontFamily: 'Montserrat', // 使用更现代的字体
                            ),
                            textAlign: TextAlign.center,
                          )
                              .animate()
                              .fade(duration: 600.ms)
                              .slideY(
                            begin: -0.6, // 更大的滑动距离
                            end: 0,
                            curve: Curves.easeOut,
                            duration: 600.ms,
                          ),
                          const SizedBox(height: 48),

                          // 邮箱输入框
                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            decoration: InputDecoration(
                              labelText: '邮箱',
                              hintText: '请输入你的邮箱',
                              prefixIcon: const Icon(Icons.email_outlined, // 使用轮廓图标
                                  color: Color(0xFF64B5F6)), // 较亮的蓝色
                              filled: true,
                              fillColor: const Color(0xFFF7FAFC), // 极浅的蓝色
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18), // 更圆润的边框
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                    color: Color(0xFF64B5F6), width: 2.5), // 更宽的边框
                              ),
                              labelStyle: TextStyle(
                                  color: _emailFocusNode.hasFocus
                                      ? const Color(0xFF64B5F6)
                                      : const Color(0xFF718096)), // 灰蓝色标签
                              hintStyle:
                              const TextStyle(color: Color(0xFFB0BEC5)), // 浅灰色提示
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
                          )
                              .animate(target: _emailFocusNode.hasFocus ? 1 : 0)
                              .scaleXY(
                            begin: 0.98,
                            end: 1,
                            curve: Curves.easeOut,
                            duration: 200.ms,
                          ),

                          const SizedBox(height: 28),

                          // 密码输入框
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            decoration: InputDecoration(
                              labelText: '密码',
                              hintText: '请输入你的密码',
                              prefixIcon: const Icon(Icons.lock_outline, // 使用轮廓图标
                                  color: Color(0xFF64B5F6)),
                              filled: true,
                              fillColor: const Color(0xFFF7FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                    color: Color(0xFF64B5F6), width: 2.5),
                              ),
                              labelStyle: TextStyle(
                                  color: _passwordFocusNode.hasFocus
                                      ? const Color(0xFF64B5F6)
                                      : const Color(0xFF718096)),
                              hintStyle:
                              const TextStyle(color: Color(0xFFB0BEC5)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined, // 使用轮廓图标
                                  color: const Color(0xFF64B5F6),
                                ),
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
                          )
                              .animate(
                              target: _passwordFocusNode.hasFocus ? 1 : 0)
                              .scaleXY(
                            begin: 0.98,
                            end: 1,
                            curve: Curves.easeOut,
                            duration: 200.ms,
                          ),

                          const SizedBox(height: 18),

                          if (_loginError != null) ...[
                            Text(
                              _loginError!,
                              style: const TextStyle(color: Color(0xFFE57373)), // 更柔和的红色
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                          ],

                          // "记住我" 和 "自动登录"
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                activeColor: const Color(0xFF42A5F5), // 较亮的蓝色
                                checkColor: Colors.white, // 白色对勾
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6), // 小圆角
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value!;
                                  });
                                },
                              ),
                              const Text(
                                '记住我',
                                style: TextStyle(color: Color(0xFF546E7A)), // 深灰蓝色
                              ),
                              const SizedBox(width: 16),
                              Checkbox(
                                value: _autoLogin,
                                activeColor: const Color(0xFF42A5F5),
                                checkColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _autoLogin = value!;
                                  });
                                },
                              ),
                              const Text(
                                '自动登录',
                                style: TextStyle(color: Color(0xFF546E7A)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 36),

                          // 登录按钮 (使用渐变色)
                          Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20), // 更圆润的按钮
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF64B5F6).withOpacity(0.4), // 阴影颜色
                                    spreadRadius: 1,
                                    blurRadius: 10,
                                    offset: const Offset(0, 4), // 阴影偏移
                                  ),
                                ],
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF90CAF9), // 浅蓝色
                                    Color(0xFF64B5F6), // 较深的蓝色
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 20), // 更高的按钮
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  shadowColor: Colors.transparent,
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                    color: Colors.white)
                                    : const Text(
                                  '登录',
                                  style: TextStyle(
                                    fontSize: 22, // 更大的字体
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                              ))
                              .animate(target: _isLoading ? 0 : 1)
                              .scaleXY(
                            begin: 0.95,
                            end: 1,
                            curve: Curves.easeInOut,
                            duration: 300.ms,
                          ),

                          const SizedBox(height: 24),

                          // "忘记密码" 和 "注册" 按钮
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: _showContactDialog,
                                child: const Text(
                                  '忘记密码？',
                                  style: TextStyle(
                                      color: Color(0xFF718096), // 灰蓝色
                                      fontWeight: FontWeight.w600, // 更粗的字体
                                      fontFamily: 'Montserrat'
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  '没有账号？去注册',
                                  style: TextStyle(
                                    color: Color(0xFF64B5F6),
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Montserrat',
                                  ),
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
          ),
        ),
      ),
      
    );
    
  }
}