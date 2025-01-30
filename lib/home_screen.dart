import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'send_letter_screen.dart';
import 'letter_detail_screen.dart';
import 'unread_letter_screen.dart';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _cardBorderRadius = 8.0;
  int _selectedIndex = 0;

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
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                ),
                child: Text('菜单',
                    style: TextStyle(fontSize: 24, color: Colors.black87)),
              ),
              ListTile(
                leading: Icon(Icons.home, color: Colors.black87),
                title: Text('主页', style: TextStyle(color: Colors.black87)),
                selected: _selectedIndex == 0,
                onTap: () {
                   _updateSelectedIndex(0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                  leading: Icon(Icons.mail, color: Colors.black87),
                  title: Text('写信', style: TextStyle(color: Colors.black87)),
                  selected: _selectedIndex == 1,
                  onTap: () {
                    _updateSelectedIndex(1);
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => SendLetterScreen()));
                  }),
            ],
          )
        ],
      ),
    );
  }

    void _updateSelectedIndex(int index){
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
            _buildAppBar(context),
            SizedBox(height: 16),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildDashboardView(context),
                ],
              ),
            ),
          ],
        ));
  }

  Widget _buildAppBar(BuildContext context) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.menu, size: 30, color: Colors.black87),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          Text(
            '我的应用',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(width: 48),
        ]);
  }

  Widget _buildDashboardView(BuildContext context) {
    return Column(
      children: [
        _buildDashboardCard(
            context,
            icon: Icons.mail_outline,
            title: '未读信件',
            valueFuture: fetchUnreadLetterCount(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => UnreadLetterScreen()));
            }
        ),
        _buildDashboardCard(
          context,
          icon: Icons.send_outlined,
          title: '已发送信件',
          valueFuture: fetchSentLetterCount(),
          onTap: () {
           //跳转到已发送页面
          },
        ),
         _buildDashboardCard(
          context,
          icon: Icons.edit_outlined,
          title: '发送信件',
           valueFuture: Future.value(''),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => SendLetterScreen()));
          }
         ),
         _buildContactsCard(context),
      ],
    );
  }
   Widget _buildContactsCard(BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardBorderRadius)),
      color: Colors.grey[50],
      child: Padding(
          padding: const EdgeInsets.all(16.0),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                 Text('常用联系人',
                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                     Icon(Icons.group_outlined, size: 20, color: Colors.grey[700]),
                   ],
               ),
               SizedBox(height: 10),
              FutureBuilder<List<String>>(
                future: fetchRecentContacts(),
                  builder: (context, snapshot) {
                      if(snapshot.connectionState == ConnectionState.waiting){
                        return CircularProgressIndicator();
                      }else if (snapshot.hasError){
                         return Text('Error', style: TextStyle(color: Colors.red));
                      }else if(snapshot.hasData && snapshot.data!.isNotEmpty){
                        return  Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: snapshot.data!.map((name) =>
                               Padding(
                                 padding: const EdgeInsets.symmetric(vertical: 4.0),
                                   child: Text(name, style: TextStyle(color: Colors.grey[700])),
                               ),
                             ).toList(),
                            );
                      }else{
                         return Text('无常用联系人',  style: TextStyle(color: Colors.grey[500]));
                      }
                 },
              ),
           ],
       ),
        ),
     );
 }

  Widget _buildDashboardCard(BuildContext context,
      {required IconData icon,
      required String title,
      required Future<dynamic> valueFuture,
      required VoidCallback onTap}) {
    return Card(
      elevation: 1,
        margin: EdgeInsets.symmetric(vertical: 8),
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
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87)),
                    SizedBox(height: 4),
                    FutureBuilder(
                      future: valueFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text('Error',
                              style: TextStyle(color: Colors.red));
                        } else {
                          return Text(snapshot.data.toString(),
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey[700]));
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

     Future<int> fetchUnreadLetterCount() async {
      try {
          final prefs = await SharedPreferences.getInstance();
            final currentUserId = prefs.getString('current_user_id') ?? '';
         final response = await Supabase.instance.client
          .from('students')
          .select('name, class_name')
          .eq('student_id', currentUserId)
          .single();

       final studentData = response;
        final lettersResponse = await Supabase.instance.client
          .from('letters')
          .select()
        .eq('receiver_name', studentData['name'])
          .eq('receiver_class', studentData['class_name']);
         return lettersResponse.length;
         }on PostgrestException catch (e) {
         print('获取未读信件数量发生 Supabase 错误: ${e.message}');
          return 0;
         }
         catch (e){
        print('获取未读信件数量发生其他错误：$e');
            return 0;
       }
  }
    Future<int> fetchSentLetterCount() async {
    try {
        final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('current_user_id') ?? '';

    final sentLettersResponse = await Supabase.instance.client
          .from('letters')
          .select()
        .eq('sender_id', currentUserId);
         return sentLettersResponse.length;

    }  on PostgrestException catch (e){
         print('获取已发送信件数量发生 Supabase 错误: ${e.message}');
       return 0;
     } catch (e){
         print('获取已发送信件数量发生其他错误：$e');
         return 0;
    }
  }

  Future<List<String>> fetchRecentContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('current_user_id') ?? '';

      final response = await Supabase.instance.client
          .from('letters')
          .select('receiver_name')
          .eq('sender_id', currentUserId)
          .limit(5);

      List<String> names =
          response.map((e) => e['receiver_name'].toString()).toList();
      return names;
    } on PostgrestException catch (e) {
      print('获取常用联系人发生 Supabase 错误: ${e.message}');
      return [];
    } catch (e) {
      print('获取常用联系人发生其他错误：$e');
      return [];
    }
  }
}
Future<List<Map<String, dynamic>>> fetchLetters() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('current_user_id') ?? '';

    final response = await Supabase.instance.client
        .from('students')
        .select('name, class_name')
        .eq('student_id', currentUserId)
        .single();

    final studentData = response;

    final lettersResponse = await Supabase.instance.client
        .from('letters')
        .select()
        .eq('receiver_name', studentData['name'])
        .eq('receiver_class', studentData['class_name']);
    return lettersResponse;
  } on PostgrestException catch (e) {
    print('获取信件数据发生 Supabase 错误: ${e.message}');
    return [];
  } catch (e) {
    print('获取信件数据发生其他错误：$e');
    return [];
  }
}