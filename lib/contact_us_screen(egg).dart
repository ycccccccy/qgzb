import 'package:flutter/material.dart';
import 'global_appbar.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  void _showEggPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text(
              '彩蛋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // 动态星空背景
              AnimatedContainer(
                duration: const Duration(seconds: 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade900, Colors.purple.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              
              // 彩蛋内容
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 动态旋转的彩蛋图标
                      AnimatedRotation(
                        duration: const Duration(seconds: 5),
                        turns: 1,
                        child: Icon(
                          Icons.celebration,
                          size: 60,
                          color: Colors.amber.shade300,
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // 分段式渐显文字
                      _buildAnimatedText(
                        text: "📮 检测到时空穿越者信号：",
                        delay: 0,
                      ),
                      _buildAnimatedText(
                        text: "「看得出来你挺闲的」",
                        delay: 1,
                        color: Colors.cyanAccent,
                      ),
                      _buildAnimatedText(
                        text: "🎯 彩蛋猎人成就解锁：",
                        delay: 2,
                      ),
                      _buildAnimatedText(
                        text: "发现第114514号校园星轨的隐藏坐标",
                        delay: 3,
                        color: Colors.pinkAccent,
                      ),
                      _buildAnimatedText(
                        text: "🌟 正在加载你的专属青春：",
                        delay: 4,
                      ),
                      _buildAnimatedText(
                        text: "进度■■■■□ 80%...",
                        delay: 5,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 18,
                          color: Colors.limeAccent,
                        ),
                      ),
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

  Widget _buildAnimatedText({
    required String text,
    required int delay,
    Color? color,
    TextStyle? style,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(20 * (1 - value), 0),
            child: Text(
              text,
              style: style ?? TextStyle(
                fontSize: 16,
                color: color ?? Colors.white70,
                fontWeight: FontWeight.w300,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
      child: Text(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: GlobalAppBar(title: '关于我们', showBackButton: true, actions: []),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 原联系信息部分保持不变
              const Text(
                '联系方式',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              const Text(
                '邮箱：',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
              InkWell(
                onTap: () => _showEggPage(context),
                child: Text(
                  '3646834681@qq.com / liujingxuan200705@163.com',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[700],
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '微信：',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
              InkWell(
                onTap: () => _showEggPage(context),
                child: Text(
                  'x2463274',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[700],
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 20),
             
              // 原理念部分保持不变
              const Text(
                '我们的理念',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Text(
                '校园不应是信息的孤岛，我们正在构建跨越山河的温暖星轨，通过文字的光年跋涉，让每份真挚都能抵达应往的远方。',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 10),
              Text(
                '在这里，快乐会翻越围墙成为双份喜悦，烦恼将穿越云端化作轻羽飘散。我们相信文字是最古老的桥梁，让隔屏相望的灵魂，在字里行间听见彼此的心跳。',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 10),
              Text(
                '匿名不是隔阂的面具，而是打开心房的钥匙。褪去现实身份的重负，让纯粹的情感自由流淌。',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 10),
              Text(
                '每一段坦诚的文字都是星火，终将点燃理解与共鸣的璀璨星河。',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 10),
              Text(
                '本项目完全公益，我们不会收取任何费用，也不会泄露任何个人信息。我们相信，每一封信都是一份真挚，每一份真挚都值得被尊重。',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}