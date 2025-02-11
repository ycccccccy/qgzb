//home_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'api_service.dart'; // 导入 api_service.dart
import 'models.dart';
import 'send_letter_screen.dart';
import 'received_letter_screen.dart';
import 'sent_letters_screen.dart';
import 'settings_screen.dart';
import 'global_appbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final double _cardBorderRadius = 8.0;
  int _selectedIndex = 0;
  ApiService? _apiService; // 使用 ApiService
  DataService? _dataService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(); // 直接创建 ApiService 实例
    _dataService = DataService(apiService: _apiService!);
    _dataService?.loadInitialData();
  }

  @override
  void dispose() {
    _dataService?.dispose();
    super.dispose();
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: null, // 隐藏默认的 AppBar
      drawer: _buildDrawer(),
      body: SafeArea(
        child: _buildMainContent(context),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.transparent, // 透明背景
                ),
                child: Text(
                  '菜单',
                  style: TextStyle(fontSize: 24, color: Colors.black87),
                ),
              ),
              _buildDrawerItem(
                icon: Icons.home,
                title: '主页',
                index: 0,
                onTap: () {
                  _updateSelectedIndex(0);
                  Navigator.pop(context); // 关闭抽屉
                },
              ),
              _buildDrawerItem(
                icon: Icons.mail,
                title: '写信',
                index: 1,
                onTap: () {
                  _updateSelectedIndex(1);
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SendLetterScreen()));
                },
              ),
              _buildDrawerItem(
                icon: Icons.settings,
                title: '设置',
                index: 2,
                onTap: () {
                  _updateSelectedIndex(2);
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SettingsScreen()));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

    Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(color: Colors.black87)),
      selected: _selectedIndex == index,
      onTap: onTap,
    );
  }

  void _updateSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
    Widget _buildMainContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile =
        screenWidth < 600; // 假设小于 600 宽度认为是移动设备，你可以根据需要调整

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32), // 根据是否为移动设备调整边距
      child: Column(
        children: [
          const GlobalAppBar(title: '我的应用', showBackButton: true, actions: []),
          const SizedBox(height: 16),
          Expanded(
            child:  _dataService != null
                    ? (_selectedIndex == 0
                        ? _buildDashboardView(context)
                        : _selectedIndex == 1
                            ? Container() // 占位符，根据需要替换
                            : _selectedIndex == 2
                                ? Container() // 占位符，根据需要替换
                                : Container())
                    : const Center(child: CircularProgressIndicator())
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardView(BuildContext context) {
    return Column(
      children: [
        _buildDashboardCard(
          context,
          icon: Icons.mail_outline,
          title: '收件箱',
          valueNotifier: _dataService!.receivedLetterCountNotifier,
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ReceivedLetterScreen()));
          },
        ),
        _buildDashboardCard(
          context,
          icon: Icons.send_outlined,
          title: '已发送信件',
          valueNotifier: _dataService!.sentLetterCountNotifier,
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SentLettersScreen()));
          },
        ),
        _buildDashboardCard(
          context,
          icon: Icons.edit_outlined,
          title: '发送信件',
          valueNotifier: ValueNotifier(''), // 发送信件卡片不需要 ValueNotifier
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SendLetterScreen()));
          },
        ),
        _buildContactsCard(context), // 最近联系人
      ],
    );
  }

    Widget _buildContactsCard(BuildContext context) {
    return Card(
      elevation: 1, // 卡片阴影
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardBorderRadius)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '常用联系人',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                Icon(Icons.group_outlined, size: 20, color: Colors.grey[700]),
              ],
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<List<String>>(
              valueListenable: _dataService!.recentContactsNotifier,
              builder: (context, contacts, _) {
                if (contacts.isEmpty) {
                  return Text('无常用联系人',
                      style: TextStyle(color: Colors.grey[500])); // 提示信息
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: contacts
                      .map((name) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(name,
                                style: TextStyle(color: Colors.grey[700])),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required ValueNotifier valueNotifier,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardBorderRadius)),
      color: Colors.grey[50], // 卡片背景色
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 24, color: Colors.blue), // 卡片图标
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder(
                      valueListenable: valueNotifier,
                      builder: (context, value, _) {
                        return Text(
                          value.toString(),
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[700]),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DataService {
  final ApiService apiService; // 使用 ApiService
  final receivedLetterCountNotifier = ValueNotifier<int>(0);
  final sentLetterCountNotifier = ValueNotifier<int>(0);
  final recentContactsNotifier = ValueNotifier<List<String>>([]);

  DataService({required this.apiService});

  Future<void> loadInitialData() async {
    await _fetchSentLetterCount();
    await _fetchRecentContacts();
     await _fetchReceivedLetters();  // 获取收件箱
  }

    void dispose() {
    receivedLetterCountNotifier.dispose();
    sentLetterCountNotifier.dispose();
    recentContactsNotifier.dispose();
  }

 List<Letter> _receivedLetters = [];

  Future<void> _fetchReceivedLetters() async {
    try {

        final letters = await apiService.getReceivedLetters(); // 使用 apiService
        _receivedLetters = letters;
        _updateReceivedLetterCount();

    } catch (e) {
       receivedLetterCountNotifier.value = 0;
    }
  }

// 更新收件箱数量 (所有收到的信件，不再需要检查 isRead)
  void _updateReceivedLetterCount() {
    receivedLetterCountNotifier.value = _receivedLetters.length;
  }

  Future<void> _fetchSentLetterCount() async {
    try {

        final letters = await apiService.getSentLetters(); // 使用 apiService
        sentLetterCountNotifier.value = letters.length;

    } catch (e) {
      sentLetterCountNotifier.value = 0; // 设置初始值
    }
  }

  Future<void> _fetchRecentContacts() async {
    try {

        final contacts = await apiService.getRecentContacts(); // 使用 apiService
        recentContactsNotifier.value = contacts;

    } catch (e) {
      recentContactsNotifier.value = []; // 设置初始值
    }
  }
}