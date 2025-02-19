import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'models.dart';
import 'send_letter_screen.dart';
import 'received_letter_screen.dart';
import 'sent_letters_screen.dart';
import 'global_appbar.dart';

// 常量
const Color _primaryColor = Color(0xFF64B5F6);
const Color _textColor = Color(0xFF34495E);
const Color _greyColor = Color(0xFF718096);
const Color _backgroundColor = Color(0xFFF7FAFC); // 浅蓝灰色背景
const Color _whiteColor = Color(0xFFFFFFFF); // 白色
const double _cardBorderRadius = 16.0; // 增加圆角半径
const double _horizontalPadding = 20.0; // 水平内边距

// SharedPreferences 键
const String _rememberedNameKey = 'rememberedName';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _selectedIndex = 0;
  ApiService? _apiService;
  DataService? _dataService;
  String _userName = '';
  String _userGreeting = '';
  String _oneWord = ''; // 一言

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _dataService = DataService(apiService: _apiService!);
    _dataService?.loadInitialData();
    _loadUserData();
    _fetchOneWord();
  }

  @override
  void dispose() {
    _dataService?.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString(_rememberedNameKey) ?? '用户';
      _userGreeting = _getGreeting();
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return '早上好';
    } else if (hour >= 11 && hour < 13) {
      return '中午好';
    } else if (hour >= 13 && hour < 18) {
      return '下午好';
    } else {
      return '晚上好';
    }
  }

  Future<void> _fetchOneWord() async {
    try {
      final response =
          await http.get(Uri.parse('https://v1.hitokoto.cn/?encode=json'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _oneWord = data['hitokoto'];
        });
      } else {
        setState(() {
          _oneWord = '获取一言失败';
        });
      }
    } catch (e) {
      setState(() {
        _oneWord = '获取一言失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: null,
      extendBody: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
              top: 16.0, left: _horizontalPadding, right: _horizontalPadding),
          child: _buildMainContent(context),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlobalAppBar(title: '写信', showBackButton: true, actions: []),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            '$_userGreeting，$_userName',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
               fontFamily: 'Montserrat', // 保留您原来的字体
            ),
          ),
        ),
        const SizedBox(height: 24),

        Expanded(
            child: _dataService != null
                ? (_selectedIndex == 0
                    ? _buildDashboardView(context)
                    : Container())
                : const Center(child: CircularProgressIndicator())),

        // 一言 (居中)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Center(
            child: Text(
              _oneWord,
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardView(BuildContext context) {
    return ListView(
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
                builder: (context) => const ReceivedLetterScreen(), // 修正导航
              ),
            );
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
              MaterialPageRoute(
                builder: (context) => const SentLettersScreen(), // 修正导航
              ),
            );
          },
        ),
        _buildDashboardCard(
          context,
          icon: Icons.edit_outlined,
          title: '发送信件',
          valueNotifier: ValueNotifier(''),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SendLetterScreen(), // 修正导航
              ),
            );
          },
        ),
        _buildContactsCard(context),
      ],
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
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardBorderRadius)),
      color: _whiteColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // 微调内边距
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 26, color: _primaryColor), // 增大图标尺寸
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17, // 稍微增大字号
                        fontWeight: FontWeight.w600, // 使用半粗体
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder(
                      valueListenable: valueNotifier,
                      builder: (context, value, _) {
                        return Text(
                          value.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            color: _greyColor,
                          ),
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

  Widget _buildContactsCard(BuildContext context) {
    return Card(
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardBorderRadius)),
      color: _whiteColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中对齐
              children: [
                const Text(
                  '常用联系人',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                const Icon(Icons.group_outlined, size: 20, color: _greyColor),
              ],
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<List<String>>(
              valueListenable: _dataService!.recentContactsNotifier,
              builder: (context, contacts, _) {
                if (contacts.isEmpty) {
                  return Text('无常用联系人',
                      style: TextStyle(color: Colors.grey[600])); // 加深颜色
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: contacts
                      .map((name) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(name,
                                style: TextStyle(
                                    color: Colors.grey[700], fontSize: 15)),
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
}

class DataService {
  final ApiService apiService;
  final receivedLetterCountNotifier = ValueNotifier<int>(0);
  final sentLetterCountNotifier = ValueNotifier<int>(0);
  final recentContactsNotifier = ValueNotifier<List<String>>([]);

  DataService({required this.apiService});

  Future<void> loadInitialData() async {
    await _fetchSentLetterCount();
    await _fetchRecentContacts();
    await _fetchReceivedLetters();
  }

  void dispose() {
    receivedLetterCountNotifier.dispose();
    sentLetterCountNotifier.dispose();
    recentContactsNotifier.dispose();
  }

  List<Letter> _receivedLetters = [];

  Future<void> _fetchReceivedLetters() async {
    try {
      final letters =
          await apiService.getReceivedLetters(); // 假设你有这个方法
      _receivedLetters = letters;
      _updateReceivedLetterCount();
    } catch (e) {
      receivedLetterCountNotifier.value = 0;
    }
  }

  void _updateReceivedLetterCount() {
    receivedLetterCountNotifier.value = _receivedLetters.length;
  }

  Future<void> _fetchSentLetterCount() async {
    try {
      final letters = await apiService.getSentLetters(); // 假设你有这个方法
      sentLetterCountNotifier.value = letters.length;
    } catch (e) {
      sentLetterCountNotifier.value = 0;
    }
  }

  Future<void> _fetchRecentContacts() async {
    try {
      final contacts =
          await apiService.getRecentContacts(); // 假设你有这个方法
      recentContactsNotifier.value = contacts;
    } catch (e) {
      recentContactsNotifier.value = [];
    }
  }
}