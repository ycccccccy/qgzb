import 'package:flutter/material.dart';
import 'package:qgzb/Capsule_inbox.dart';
import 'sendletter_to_me.dart';
import 'sendletter_to_others.dart';
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
              const GlobalAppBar(title: '时空胶囊', showBackButton: true, actions: [],),
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
            icon: Icons.person,
            text: '给未来的自己',
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
            icon: Icons.people_alt,
            text: '给未来的Ta',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SendToOthersPage()),
            ),
          ),
         ),
         SizedBox(
           width: 280,
           child: _buildCardButton(
            context,
            icon: Icons.lock_open,
            text: '查看已解封的时空胶囊',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InboxPage()),
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