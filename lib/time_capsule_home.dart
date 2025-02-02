import 'package:flutter/material.dart';
import 'sendletter_to_me.dart';
import 'sendlettet_to_others.dart';
import 'global_appbar.dart';

class TimeCapsuleHome extends StatelessWidget {
  const TimeCapsuleHome({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: null,
      body: SafeArea(
        child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 32),
          child: Column(
            children: [
              const GlobalAppBar(title: '时间胶囊', showBackButton: true),
              Expanded(
                child: Center(
                  child: _buildButtons(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 20,
        children: [
        SizedBox(
          width: 280,
          child: _buildCardButton(
            context,
            icon: Icons.mail_outline,
            text: '给自己写信',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SendToSelfPage()),
            ),
          ),
        ),
         SizedBox(
           width: 280,
           child: _buildCardButton(
            context,
            icon: Icons.send_outlined,
            text: '给他人写信',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SendToOthersPage()),
            ),
          ),
         ),
        ],
    );
  }

  Widget _buildCardButton(BuildContext context,
      {required IconData icon, required String text, required VoidCallback onPressed}) {
    return Card(
      elevation: 4, // 阴影效果
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // 圆角
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: const Color(0xFF4A90E2)), // 图标颜色
              const SizedBox(height: 12),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333), // 文字颜色
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}