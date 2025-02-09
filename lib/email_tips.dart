import 'package:flutter/material.dart';
import 'package:hyxj/register_screen.dart';
import 'global_appbar.dart';

const double _verticalSpacing = 20.0;
const double _horizontalPadding = 24.0;
const double _cardRadius = 12.0;
const Color _textColor = Color(0xFF333333);
const Color _greyColor = Color(0xFF888888);
const Color _primaryColor = Color(0xFF4A90E2);
const double _iconSize = 28.0;

class EmailGuideScreen extends StatelessWidget {
  const EmailGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : _horizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GlobalAppBar(
                title: 'QQ邮箱使用指南',
                showBackButton: true,
                actions: [],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: _verticalSpacing),
                      _buildStepCard(
                        context,
                        stepNumber: 1,
                        title: "获取QQ邮箱地址",
                        content: "你的QQ邮箱地址就是你的QQ号码加上@qq.com\n\n"
                            "例如：如果你的QQ号是12345678\n"
                            "那么邮箱地址就是：12345678@qq.com",
                      ),
                      const SizedBox(height: _verticalSpacing),
                      _buildStepCard(
                        context,
                        stepNumber: 2,
                        title: "登录QQ邮箱",
                        content: "1. 在手机或电脑浏览器访问 mail.qq.com\n"
                            "2. 选择『QQ登录』方式\n"
                            "3. 输入你的QQ号和密码\n"
                            "4. 登录成功后即可查看收件箱",
                      ),
                      const SizedBox(height: _verticalSpacing),
                      _buildStepCard(
                        context,
                        stepNumber: 3,
                        title: "查看验证码",
                        content: "1. 完成注册后，请及时登录QQ邮箱\n"
                            "2. 在收件箱找到我们发送的验证邮件\n"
                            "3. 邮件内容中包含6位数字验证码\n"
                            "4. 将验证码填写回注册页面即可完成验证",
                      ),
                      const SizedBox(height: _verticalSpacing * 2),
                      _buildConfirmButton(context),
                      const SizedBox(height: _verticalSpacing),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(BuildContext context,
      {required int stepNumber, required String title, required String content}) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: _iconSize / 2,
              backgroundColor: _primaryColor,
              child: Text(
                stepNumber.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: _greyColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cardRadius),
          ),
        ),
        onPressed: (){
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RegisterScreen()),
            );
        },
        child: const Text(
          '我知道了，去注册',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
