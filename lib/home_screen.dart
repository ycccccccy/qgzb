import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'send_letter_screen.dart';
import 'letter_detail_screen.dart';
import 'unread_letter_screen.dart';
import 'recent_contacts_screen.dart';
import 'sent_letters_screen.dart';
import 'settings_screen.dart';
import 'global_appbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final double _cardBorderRadius = 8.0;
  int _selectedIndex = 0;
  final _dataService = DataService();

  @override
  void dispose() {
    _dataService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: null,
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
                  color: Colors.transparent,
                ),
                child: Text('菜单',
                    style: TextStyle(fontSize: 24, color: Colors.black87)),
              ),
              ListTile(
                leading: const Icon(Icons.home, color: Colors.black87),
                title: const Text('主页', style: TextStyle(color: Colors.black87)),
                selected: _selectedIndex == 0,
                onTap: () {
                  _updateSelectedIndex(0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                  leading: const Icon(Icons.mail, color: Colors.black87),
                  title: const Text('写信', style: TextStyle(color: Colors.black87)),
                  selected: _selectedIndex == 1,
                  onTap: () {
                    _updateSelectedIndex(1);
                    Navigator.pop(context);
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SendLetterScreen()));
                  }),
              ListTile(
                  leading: const Icon(Icons.settings, color: Colors.black87),
                  title: const Text('设置', style: TextStyle(color: Colors.black87)),
                  selected: _selectedIndex == 2,
                  onTap: () {
                    _updateSelectedIndex(2);
                    Navigator.pop(context);
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SettingsScreen()));
                  }),
            ],
          )
        ],
      ),
    );
  }

  void _updateSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildMainContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    return Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          children: [
             GlobalAppBar(title: '我的应用', showBackButton: true), // 添加返回按钮
            const SizedBox(height: 16),
            Expanded(
              child: _selectedIndex == 0
                  ? _buildDashboardView(context)
                  : _selectedIndex == 1
                      ? Container()
                      : _selectedIndex == 2
                          ? Container()
                          : Container(),
            ),
          ],
        ));
  }

  Widget _buildDashboardView(BuildContext context) {
    return Column(
      children: [
        _buildDashboardCard(context,
            icon: Icons.mail_outline,
            title: '未读信件',
            valueStream: _dataService.fetchUnreadLetterCountStream(),
            onTap: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => UnreadLetterScreen()));
            }),
        _buildDashboardCard(
          context,
          icon: Icons.send_outlined,
          title: '已发送信件',
          valueStream: _dataService.fetchSentLetterCountStream(),
          onTap: () {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => SentLettersScreen()));
          },
        ),
        _buildDashboardCard(context,
            icon: Icons.edit_outlined,
            title: '发送信件',
            valueStream: Stream.value(''),
            onTap: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => SendLetterScreen()));
            }),
        _buildContactsCard(context),
      ],
    );
  }

  Widget _buildContactsCard(BuildContext context) {
    return Card(
      elevation: 1,
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
                const Text('常用联系人',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                Icon(Icons.group_outlined, size: 20, color: Colors.grey[700]),
              ],
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<String>>(
                stream: _dataService.fetchRecentContactsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return const Text('Error',
                        style: TextStyle(color: Colors.red));
                  } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: snapshot.data!
                          .map((name) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                child: Text(name,
                                    style: TextStyle(color: Colors.grey[700])),
                              ))
                          .toList(),
                    );
                  } else {
                    return Text('无常用联系人',
                        style: TextStyle(color: Colors.grey[500]));
                  }
                }),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context,
      {required IconData icon,
      required String title,
      required Stream<dynamic> valueStream,
      required VoidCallback onTap}) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardBorderRadius)),
      color: Colors.grey[50],
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 24, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87)),
                    const SizedBox(height: 4),
                    StreamBuilder(
                      stream: valueStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return const Text('Error',
                              style: TextStyle(color: Colors.red));
                        } else {
                          return Text(snapshot.data.toString(),
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[700]));
                        }
                      },
                    )
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
  final _unreadLetterCountController = StreamController<int>.broadcast();
  final _sentLetterCountController = StreamController<int>.broadcast();
  final _recentContactsController = StreamController<List<String>>.broadcast();
  late StreamSubscription _unreadSubscription;
  late StreamSubscription _sentSubscription;
  late StreamSubscription _recentContactsSubscription;


  DataService() {
    _loadInitialData();
  }

  void dispose() {
      _unreadSubscription.cancel();
      _sentSubscription.cancel();
      _recentContactsSubscription.cancel();
    _unreadLetterCountController.close();
    _sentLetterCountController.close();
    _recentContactsController.close();
  }

  Future<void> _loadInitialData() async {
    _unreadSubscription = fetchUnreadLetterCountStream().listen((count) {
      _unreadLetterCountController.add(count);
    });
    _sentSubscription = fetchSentLetterCountStream().listen((count) {
      _sentLetterCountController.add(count);
    });
    _recentContactsSubscription = fetchRecentContactsStream().listen((contacts) {
      _recentContactsController.add(contacts);
    });
  }

  Stream<int> fetchUnreadLetterCountStream() async* {
    while (true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentUserId = prefs.getString('current_user_id') ?? '';
        final response = await Supabase.instance.client
            .from('students')
            .select('name, class_name, allow_anonymous,school')
            .eq('student_id', currentUserId)
            .single();

        final studentData = response;
        final allowAnonymous = studentData['allow_anonymous'] ?? false;

        final query = Supabase.instance.client
            .from('letters')
            .select()
            .or(
                'and(receiver_name.eq.${studentData['name']},my_school.eq.${studentData['school']}),and(receiver_name.eq.${studentData['name']},target_school.eq.${studentData['school']})');

        final lettersResponse = await query;
        final myClass = studentData['class_name'];
        final List<Map<String, dynamic>> filteredLetters;
        if (!allowAnonymous) {
          filteredLetters = lettersResponse
              .where((letter) =>
                  (letter['is_anonymous'] == false ||
                      letter['is_anonymous'] == null) &&
                  (letter['receiver_class'] == myClass ||
                      letter['receiver_class'] == null))
              .toList();
        } else {
          filteredLetters = lettersResponse
              .where((letter) =>
                  (letter['receiver_class'] == myClass ||
                      letter['receiver_class'] == null))
              .toList();
        }
        yield filteredLetters.length;
      } on PostgrestException catch (e) {
        print('获取未读信件数量发生 Supabase 错误: ${e.message}');
        yield 0;
      } catch (e) {
        print('获取未读信件数量发生其他错误：$e');
        yield 0;
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Stream<int> fetchSentLetterCountStream() async* {
    while (true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentUserId = prefs.getString('current_user_id') ?? '';

        final sentLettersResponse = await Supabase.instance.client
            .from('letters')
            .select()
            .eq('sender_id', currentUserId);
        yield sentLettersResponse.length;
      } on PostgrestException catch (e) {
        print('获取已发送信件数量发生 Supabase 错误: ${e.message}');
        yield 0;
      } catch (e) {
        print('获取已发送信件数量发生其他错误：$e');
        yield 0;
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Stream<List<String>> fetchRecentContactsStream() async* {
    while (true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentUserId = prefs.getString('current_user_id') ?? '';

        final response = await Supabase.instance.client
            .from('letters')
            .select('receiver_name')
            .eq('sender_id', currentUserId)
            .limit(5);

        List<String> names = response
            .map((e) => e['receiver_name'].toString())
            .toList()
            .toSet()
            .toList();
        yield names;
      } on PostgrestException catch (e) {
        print('获取常用联系人发生 Supabase 错误: ${e.message}');
        yield [];
      } catch (e) {
        print('获取常用联系人发生其他错误：$e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }
}