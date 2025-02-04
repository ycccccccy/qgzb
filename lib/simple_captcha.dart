import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SimpleCaptcha extends StatefulWidget {
  final ValueChanged<String> onCompleted;
    final bool isDialog; // 添加一个 isDialog 字段

  const SimpleCaptcha({super.key, required this.onCompleted, this.isDialog = false}); // isDialog默认为 false

  @override
  _SimpleCaptchaState createState() => _SimpleCaptchaState();
}

class _SimpleCaptchaState extends State<SimpleCaptcha> {
  String _captchaCode = '';
  final TextEditingController _textEditingController = TextEditingController();
  Color _textColor = Colors.black;
  Color _backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _generateCaptcha();
  }

 void _generateCaptcha() {
    final random = Random();
    _captchaCode = String.fromCharCodes(
        List.generate(4, (_) => _captchaChars.codeUnitAt(random.nextInt(_captchaChars.length))));
    _textColor = Color.fromRGBO(
      random.nextInt(200) + 56,
      random.nextInt(200) + 56,
      random.nextInt(200) + 56,
      1,
    );
    _backgroundColor = Color.fromRGBO(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      0.3,
    );

    setState(() {});
  }



  @override
  Widget build(BuildContext context) {
    return Column(
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
              ),
             child: Text(
                _captchaCode,
                style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: _textColor,
               ),
              ),
           ),
      ),
        const SizedBox(height: 10),
        TextField(
          controller: _textEditingController,  
          keyboardType: TextInputType.visiblePassword,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')), // 只允许英文和数字
          ],       
          decoration: InputDecoration(
            hintText: '请输入验证码',
            filled: true,
           fillColor: Colors.white,
              border: widget.isDialog ? OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ) : const OutlineInputBorder(),
            ),
          onChanged: (value) {
            if (value.length == 4) {
              if (value.toLowerCase() == _captchaCode.toLowerCase()) {
                widget.onCompleted(value);
              } else {
                  _generateCaptcha();
                _textEditingController.clear();
                setState(() {});
              }
            }
          },
        ),
      ],
    );
  }
}

const _captchaChars = 'abcdefghijklmnopqrstuvwxyz0123456789';