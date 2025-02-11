import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart'; // 导入 ApiService
import 'school_data.dart'; // 假设你有这个文件，包含学校数据
import 'login_screen.dart';

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
  bool _canRegister = true; // 控制是否可以注册 (防止重复提交)
  String? _selectedGrade;
  int? _selectedClass;
  String? _selectedClassName; // 拼接后的班级名称，例如 "高一1班"
  String? _selectedDistrict; // 区
  String? _selectedSchool;   // 学校

  final _apiService = ApiService(); // 使用 ApiService

  @override
  void dispose() {
    _emailController.dispose();
    _studentIdController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 更新 _selectedClassName
  void _updateClassValue() {
    if (_selectedGrade != null && _selectedClass != null) {
      setState(() {
        _selectedClassName = '$_selectedGrade${_selectedClass}班';
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
    final school = _selectedSchool!;  // 非空断言，因为如果表单验证通过，这些值一定不为空
    final className = _selectedClassName!;
    final password = _passwordController.text;

    try {
      // 调用 ApiService 的 registerStep1 方法
      await _apiService.registerStep1(
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
      _resetRegisterState(); // 重置注册状态
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
    String? verificationToken;    // 存储验证 token

    showDialog(
      context: context,
      barrierDismissible: false, // 点击对话框外部不会关闭
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
                Navigator.of(dialogContext).pop(); // 关闭对话框
                _resetRegisterState(); // 重置注册状态
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
                  // 调用 ApiService 的 verifyEmailCode 方法, 获取验证token
                  verificationToken =
                      await _apiService.verifyEmailCode(email, code);

                  if (verificationToken != null) {
                    // 验证码正确, 调用 ApiService 的 createUser 方法, 传递验证 token
                    await _apiService.createUser(
                      email: email,
                      studentId: studentId,
                      name: name,
                      school: school,
                      className: className,
                      password: _passwordController.text, // 传递明文密码
                      verificationToken: verificationToken!, //传递token
                    );

                    shouldNavigate = true; // 标记需要导航
                    if (mounted) _showSuccessSnackBar('注册成功！');
                  }
                } catch (e) {
                  // 验证码错误 或 创建用户失败
                  if (mounted) {
                    _showErrorSnackBar(e.toString()); // 显示详细错误信息
                  }
                }

                if (mounted) {
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

  // 构建文本输入框 (可以提取成一个独立的 Widget)
  TextFormField buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false, // 是否隐藏文本 (用于密码框)
    IconButton? suffixIcon, // 尾部图标 (用于密码可见性切换)
    String? Function(String?)? validator, // 验证函数
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
          borderSide: BorderSide.none, // 不要边框线
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600; // 假设小于 600 宽度认为是移动设备

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 20 : 40), // 根据是否为移动设备调整边距
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
                    // 邮箱
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
                        // 简单的邮箱格式验证 (可以根据需要调整)
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return '邮箱格式不正确';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // 学号
                    buildTextFormField(
                      controller: _studentIdController,
                      labelText: '学号',
                      hintText: '请输入你的学号',
                      prefixIcon: Icons.school,
                      keyboardType: TextInputType.number, // 限制为数字键盘
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly // 只允许输入数字
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '学号不能为空';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // 姓名
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

                    // 区 (Dropdown)
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
                      items: schoolList.keys // 从 school_data.dart 获取区列表
                          .map((district) => DropdownMenuItem(
                                value: district,
                                child: Text(district),
                              ))
                          .toList(),
                      onChanged: (value) {
                        // 当区改变时，重置学校、年级、班级
                        setState(() {
                          _selectedDistrict = value;
                          _selectedSchool = null; // 清空学校
                          _selectedGrade = null;
                          _selectedClass = null;
                          _updateClassValue(); // 更新班级名称
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

                    // 学校 (Dropdown)
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
                      // 根据选择的区显示学校列表
                      items: _selectedDistrict != null
                          ? schoolList[_selectedDistrict]
                              ?.map((school) => DropdownMenuItem(
                                    value: school,
                                    child: Text(school),
                                  ))
                              .toList()
                          : [], // 如果没有选择区，则显示空列表
                      onChanged: (value) {
                        // 当学校改变时，重置年级、班级
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

                    // 年级和班级 (两个 Dropdown，水平排列)
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
                            ] // 年级列表
                                .map((grade) => DropdownMenuItem(
                                      value: grade,
                                      child: Text(grade),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              // 当年级改变时，重置班级
                              setState(() {
                                _selectedGrade = value;
                                _selectedClass = null; // 清空班级
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
                        const SizedBox(width: 16), // 年级和班级之间的间距
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
                            // 生成 1 到 50 的班级列表 (你可以根据实际情况调整)
                            items: List.generate(50, (index) => index + 1)
                                .map((classNum) => DropdownMenuItem(
                                      value: classNum,
                                      child: Text('$classNum班'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedClass = value;
                                _updateClassValue(); // 更新班级名称
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
                    // 密码
                    buildTextFormField(
                      controller: _passwordController,
                      labelText: '密码',
                      hintText: '请输入你的密码',
                      prefixIcon: Icons.lock,
                      obscureText: !_passwordVisible, // 根据 _passwordVisible 切换可见性
                      suffixIcon: IconButton(
                        icon: Icon(_passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible; // 切换可见性
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

                    // 注册按钮
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _handleRegister, // 如果正在加载，禁用按钮
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
                                  fontSize: 18, color: Colors.white)), // 如果正在加载,显示指示器
                    ),
                    const SizedBox(height: 10),

                    // 登录链接
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