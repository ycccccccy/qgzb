import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SimpleCaptcha extends StatefulWidget {
  final ValueChanged<String> onCompleted;
  final bool isDialog;
  final String? errorMessage; // 新增：错误信息

  const SimpleCaptcha({
    super.key,
    required this.onCompleted,
    this.isDialog = false,
    this.errorMessage,
  });

  @override
  _SimpleCaptchaState createState() => _SimpleCaptchaState();
}

class _SimpleCaptchaState extends State<SimpleCaptcha> {
  String _captchaCode = '';
  final TextEditingController _textEditingController = TextEditingController();
  final _focusNode = FocusNode(); // 新增：焦点控制
  Color _textColor = Colors.black;
  Color _backgroundColor = Colors.white;


  @override
  void initState() {
    super.initState();
    _generateCaptcha();
    // 自动获取焦点 (可选)
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   FocusScope.of(context).requestFocus(_focusNode);
    // });
  }
  @override
  void dispose() {
    _focusNode.dispose(); // 释放焦点
    super.dispose();
  }

  void _generateCaptcha() {
    final random = Random();
    _captchaCode = String.fromCharCodes(
      List.generate(
          4,
          (_) => _CAPTCHA_CHARS.codeUnitAt(
              random.nextInt(_CAPTCHA_CHARS.length))),
    );

    _textColor = Color.fromRGBO(
    random.nextInt(156) + 100, // 使颜色更深一些
    random.nextInt(156) + 100,
    random.nextInt(156) + 100,
    1,
    );
    _backgroundColor = Color.fromRGBO(
    random.nextInt(256),
    random.nextInt(256),
    random.nextInt(256),
    0.15, // 降低不透明度
    );


    _textEditingController.clear(); // 清空输入框
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // 重要：使 Column 适应内容大小
      children: [
        InkWell(
          onTap: _generateCaptcha,
          child: Container(
            alignment: Alignment.center,
            width: 150,
            height: 60,
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!, width: 1), // 添加边框
              boxShadow: [ // 添加阴影
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _captchaCode,
              style: TextStyle(
                fontSize: 36, // 稍微减小字体大小
                fontWeight: FontWeight.bold,
                color: _textColor,
                letterSpacing: 6, // 增加字符间距
              ),
            ),
          ),
        ),
        const SizedBox(height: 16), // 增加间距
        TextField(
          controller: _textEditingController,
          focusNode: _focusNode, // 绑定焦点
          keyboardType: TextInputType.visiblePassword,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
          ],
          decoration: InputDecoration(
            hintText: '请输入验证码',
            filled: true,
            fillColor: Colors.white,
              border: widget.isDialog ? OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ) : const OutlineInputBorder(),
            errorText: widget.errorMessage, // 显示错误信息
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 调整内边距
          ),
          onChanged: (value) {
            if (value.length == 4) {
              if (value.toLowerCase() == _captchaCode.toLowerCase()) {
                widget.onCompleted(value);
                _generateCaptcha(); // 验证成功后也刷新
              } else {
                 _generateCaptcha();  //只需要重新生成.
              }
            }
          },
        ),
      ],
    );
  }
}

const _CAPTCHA_CHARS = 'abcdefghijklmnopqrstuvwxyz0123456789';