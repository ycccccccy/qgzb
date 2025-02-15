import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'api_service.dart'; // 导入 ApiService
import 'school_data.dart'; // 假设你有这个文件，包含学校数据
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;
  bool _canRegister = true; // 控制是否可以注册 (防止重复提交)
  String? _selectedGrade;
  int? _selectedClass;
  String? _selectedClassName; // 拼接后的班级名称，例如 "高一1班"
  String? _selectedDistrict; // 区
  String? _selectedSchool; // 学校

  final _apiService = ApiService(); // 使用 ApiService

  late AnimationController _controller; // 动画控制器
  late Animation<double> _cardScaleAnimation;
  late Animation<Offset> _cardSlideAnimation;

  @override
  void initState() {
    super.initState();

// 初始化动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), //动画时长增加
    );

    _cardScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _cardSlideAnimation = Tween<Offset>(
      //卡片入场动画
      begin: const Offset(0, 0.3), // 从下方30%的位置开始
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut, // 使用缓出效果
      ),
    );

    _controller.forward(); // 启动动画
  }

  @override
  void dispose() {
    _emailController.dispose();
    _studentIdController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _controller.dispose(); // 释放动画控制器
    super.dispose();
  }

// 更新 _selectedClassName
  void _updateClassValue() {
    if (_selectedGrade != null && _selectedClass != null) {
      setState(() {
        _selectedClassName = '$_selectedGrade$_selectedClass班';
      });
    } else {
      setState(() {
        _selectedClassName = null; // 如果年级或班级为空，则清空班级名称
      });
    }
  }

// 处理注册按钮点击
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate() || !_canRegister) {
      return; // 表单验证失败或正在注册中，直接返回
    }

    setState(() {
      _isLoading = true;
      _canRegister = false; // 禁用注册按钮
    });

    final email = _emailController.text.trim();
    final studentId = _studentIdController.text.trim();
    final name = _nameController.text.trim();
    final school = _selectedSchool!; // 非空断言，因为如果表单验证通过，这些值一定不为空
    final className = _selectedClassName!;
    final password = _passwordController.text;

    try {
      // 调用 ApiService 的 registerStep1 方法
      await _apiService.registerStep1(  //  添加 await
        email: email,
        studentId: studentId,
        name: name,
        school: school,
        className: className,
        password: password,
      );

      // 注册请求成功，显示邮箱验证对话框
      if (mounted) {
        _showEmailVerificationDialog(
          context,
          email,
          studentId,
          name,
          school,
          className,
        );
      }
    } catch (e) {
      // 处理注册失败的情况 (ApiService 中已经抛出异常)
      if (mounted) {
        _showErrorSnackBar(e.toString()); // 显示详细的错误信息
      }

    } finally {  // 使用 finally 确保状态重置
        _resetRegisterState();
    }
  }

// 显示邮箱验证对话框, 移除所有与本地哈希相关的代码
  void _showEmailVerificationDialog(
    BuildContext context,
    String email,
    String studentId,
    String name,
    String school,
    String className,
  ) {
    final TextEditingController verificationCodeController =
        TextEditingController();
    bool shouldNavigate = false; // 标记是否应该导航到登录页
    String? verificationToken; // 存储验证 token

    showDialog(
      context: context,
      barrierDismissible: false, // 点击对话框外部不会关闭
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5F7FA), // 更柔和的背景色
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '邮箱验证',
            style: TextStyle(color: Color(0xFF34495E)), // 深灰蓝标题
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('请输入发送到你邮箱的验证码',
                  style: TextStyle(color: Color(0xFF4A6572))), // 灰蓝色内容
              const SizedBox(height: 16),
              TextField(
                controller: verificationCodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '验证码',
                  hintText: '请输入验证码',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), // 圆角边框
                  ),
                  filled: true,
                  fillColor: Colors.white, // 白色填充
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child:
                  const Text('取消', style: TextStyle(color: Color(0xFF718096))),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // 关闭对话框
                _resetRegisterState(); // 重置注册状态
              },
            ),
            TextButton(
              child: const Text('验证',
                  style: TextStyle(color: Color(0xFF3498DB))),
              onPressed: () async {
                final code = verificationCodeController.text.trim();
                if (code.isEmpty) {
                  if (mounted)
                    _showErrorSnackBar('请输入验证码'); // 使用统一的错误提示方法
                  return;
                }

                try {
                  // 调用 ApiService 的 verifyEmailCode 方法, 获取验证token
                  verificationToken =
                      await _apiService.verifyEmailCode(email, code); // 添加 await

                  if (verificationToken != null) {
                    // 验证码正确, 调用 ApiService 的 createUser 方法, 传递验证 token
                    await _apiService.createUser(   //  添加 await
                      email: email,
                      studentId: studentId,
                      name: name,
                      school: school,
                      className: className,
                      password: _passwordController.text, // 传递明文密码
                      verificationToken: verificationToken!, //传递token
                    );

                    shouldNavigate = true; // 标记需要导航
                    if (mounted) _showSuccessSnackBar('注册成功！'); // 使用统一的成功提示方法

                  }
                } catch (e) {
                  // 验证码错误 或 创建用户失败
                  if (mounted) {
                    _showErrorSnackBar(e.toString()); // 显示详细错误信息
                  }
                }
                if(mounted){
                Navigator.of(dialogContext).pop(); // 关闭对话框
                }
                _resetRegisterState(); // 重置注册状态
              },
            ),
          ],
        );
      },
    ).then((_) {
      // 对话框关闭后，如果 shouldNavigate 为 true，则导航到登录页
      if (shouldNavigate) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

// 显示错误消息
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red, // 错误消息用红色背景
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
          backgroundColor: Colors.green, // 成功消息用绿色背景
        ),
      );
    }
  }

// 重置注册状态 (可以注册、按钮可用)
  void _resetRegisterState() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _canRegister = true; // 允许再次注册
      });
    }
  }

// 构建文本输入框 (提取成一个独立的 Widget)
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    Widget? suffixIcon,
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
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF64B5F6)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF7FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 2.5),
        ),
        labelStyle: TextStyle(
          color: controller.text.isNotEmpty
              ? const Color(0xFF64B5F6)
              : const Color(0xFF718096),

        ),
        hintStyle: const TextStyle(color: Color(0xFFB0BEC5)),
      ),
      validator: validator,
    ).animate().fade(duration: 400.ms).slideX(
        //动画时间增加
        begin: -0.3,
        end: 0,
        curve: Curves.easeOut,
        duration: 400.ms);
  }

// 构建下拉菜单 (提取成一个独立的 Widget)
  Widget _buildDropdownFormField<T>({
    required String labelText,
    required String hintText,
    required List<DropdownMenuItem<T>> items,
    required T? value,
    required void Function(T?)? onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFF7FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 2.5),
        ),
        labelStyle: TextStyle(
          color:
              value != null ? const Color(0xFF64B5F6) : const Color(0xFF718096),
        ),
        hintStyle: const TextStyle(color: Color(0xFFB0BEC5)),
      ),
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
    ).animate().fade(duration: 400.ms).slideX(
        //动画时间增加
        begin: -0.3,
        end: 0,
        curve: Curves.easeOut,
        duration: 400.ms,
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
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth), // 关键：限制最大宽度
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _cardScaleAnimation.value,
                    child: SlideTransition(
                      // 使用 SlideTransition
                      position: _cardSlideAnimation,
                      child: child,
                    ),
                  );
                },
                child: Card(
                  // 3. Card 在 AnimatedBuilder 内部
                  elevation: 10, // 增加阴影深度
                  shadowColor: Colors.black26, // 更柔和的阴影颜色
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)), // 更圆润的边角
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 标题
                          const SizedBox(height: 32),
                          Text(
                            '注册',
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

                          // 邮箱
                                                // ... (之前的代码)
                      // 邮箱
                      _buildTextFormField(
                        controller: _emailController,
                        labelText: '邮箱',
                        hintText: '请输入你的邮箱',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '邮箱不能为空';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return '邮箱格式不正确';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // 学号
                      _buildTextFormField(
                        controller: _studentIdController,
                        labelText: '学号',
                        hintText: '请输入你的学号',
                        prefixIcon: Icons.school_outlined,
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
                      const SizedBox(height: 28),

                      // 姓名
                      _buildTextFormField(
                        controller: _nameController,
                        labelText: '姓名',
                        hintText: '请输入你的姓名',
                        prefixIcon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '姓名不能为空';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // 区 (Dropdown)
                      _buildDropdownFormField<String>(
                        labelText: '区',
                        hintText: '请选择区',
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
                      const SizedBox(height: 28),

                      // 学校 (Dropdown)
                      _buildDropdownFormField<String>(
                        labelText: '学校',
                        hintText: '请选择学校',
                        value: _selectedSchool,
                        items: (_selectedDistrict != null
                                ? (schoolList[_selectedDistrict!]
                                    ?.map((school) => DropdownMenuItem(
                                          value: school,
                                          child: Text(school),
                                        ))
                                    .toList())
                                : []) ??
                            [],
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
                      const SizedBox(height: 28),

                      // 年级和班级 (两个 Dropdown，水平排列)
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownFormField<String>(
                              labelText: '年级',
                              hintText: '请选择年级',
                              value: _selectedGrade,
                              items: [
                                '初一',
                                '初二',
                                '初三',
                                '高一',
                                '高二',
                                '高三',
                              ].map((grade) => DropdownMenuItem(
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
                            child: _buildDropdownFormField<int>(
                              labelText: '班级',
                              hintText: '请选择班级',
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
                      const SizedBox(height: 28),

                      // 密码
                      _buildTextFormField(
                        controller: _passwordController,
                        labelText: '密码',
                        hintText: '请输入你的密码',
                        prefixIcon: Icons.lock_outline,
                        obscureText: !_passwordVisible,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF64B5F6),
                          ),
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
                      const SizedBox(height: 36),

                      // 注册按钮 (使用渐变色)
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
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            padding:
                                const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            shadowColor: Colors.transparent,
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  '注册',
                                  style: TextStyle(
                                    fontSize: 22, // 更大的字体
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                        ),
                      )
                          .animate(target: _isLoading ? 0 : 1)
                          .scaleXY(
                              begin: 0.95,
                              end: 1,
                              curve: Curves.easeInOut,
                              duration: 300.ms),

                      const SizedBox(height: 24),

                      // 登录链接
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()),
                          );
                        },
                        child: const Text(
                          '已有账号？去登录',
                          style: TextStyle(
                            color: Color(0xFF64B5F6),
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Montserrat',
                              ),
                            ),
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