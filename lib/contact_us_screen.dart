import 'package:flutter/material.dart';
import 'global_appbar.dart';
import 'egg.dart'; 

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: GlobalAppBar(
            title: '关于我们',
            showBackButton: true,
            actions: [],
          )),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '联系方式',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 20),
              const Text(
                '邮箱：',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EggPage()),
                  );
                },
                child: Text(
                  '3646834681@qq.com / liujingxuan200705@163.com',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '微信：',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EggPage()),
                  );
                },
                child: Text(
                  'x2463274',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '我们的理念',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Text(
                '校园不应是信息的孤岛，我们希望通过文字的光年跋涉，让每份真挚都能抵达应往的远方。',
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