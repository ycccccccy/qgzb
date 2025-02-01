import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'letter_detail_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'global_appbar.dart';

class UnreadLetterScreen extends StatefulWidget {
  @override
  _UnreadLetterScreenState createState() => _UnreadLetterScreenState();
}

class _UnreadLetterScreenState extends State<UnreadLetterScreen> {
  late Future<List<Map<String, dynamic>>> _lettersFuture;
  bool _allowAnonymous = false;

  @override
  void initState() {
    super.initState();
    _loadAnonymousSetting();
    _lettersFuture = fetchUnreadLetters();
  }

  Future<void> _loadAnonymousSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _allowAnonymous = prefs.getBool('allow_anonymous') ?? false;
    });
  }

  Future<void> _updateAnonymousSetting(bool value) async {}

  Future<List<Map<String, dynamic>>> fetchUnreadLetters() async {
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
      //print('Current User ID: $currentUserId');

      final query = Supabase.instance.client
          .from('letters')
          .select()
          .or('and(receiver_name.eq.${studentData['name']},my_school.eq.${studentData['school']}),and(receiver_name.eq.${studentData['name']},target_school.eq.${studentData['school']})');

      final lettersResponse = await query;
      //print('原始信件数据 (lettersResponse): $lettersResponse');

      final myClass = studentData['class_name'];
      List<Map<String, dynamic>> filteredLetters;
      if (!allowAnonymous) {
        filteredLetters = lettersResponse
            .where((letter) => (letter['is_anonymous'] == false || letter['is_anonymous'] == null) &&
                (letter['receiver_class'] == myClass || letter['receiver_class'] == null))
            .toList();
      } else {
        filteredLetters = lettersResponse
            .where((letter) => (letter['receiver_class'] == myClass || letter['receiver_class'] == null))
            .toList();
      }
        //print('过滤后的信件数据 (filteredLetters): $filteredLetters');
      // 获取发件人姓名
      List<Map<String, dynamic>> lettersWithSenderNames = [];
      for (var letter in filteredLetters) {
        final senderId = letter['sender_id'];
        final studentResponse = await Supabase.instance.client
            .from('students')
            .select('name')
            .eq('student_id', senderId)
            .maybeSingle();

        final senderName = studentResponse?['name'] as String?;
        lettersWithSenderNames.add({...letter, 'sender_name': senderName});
         //print('信件ID: ${letter['id']}, 发件人ID: $senderId, 发件人姓名: $senderName');
      }
      //print('最终信件数据 (lettersWithSenderNames): $lettersWithSenderNames');
      return lettersWithSenderNames;

    } on PostgrestException catch (e) {
      //print('获取信件数据发生 Supabase 错误: ${e.message}');
      return [];
    } catch (e) {
      //print('获取信件数据发生其他错误：$e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: GlobalAppBar(title: '未读信件', showBackButton: true)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _lettersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            //print('Loading...');
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            //print('Error: ${snapshot.error}');
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: TextStyle(color: Colors.red)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            //print('No data');
            return Center(
                child: Text('没有未读信件',
                    style: TextStyle(color: Colors.grey[500])));
          } else {
            //print('Data received: ${snapshot.data}');
            return ListView.separated(
              padding: EdgeInsets.all(16.0),
              itemCount: snapshot.data!.length,
              separatorBuilder: (context, index) => SizedBox(height: 8.0),
              itemBuilder: (context, index) {
                final letter = snapshot.data![index];
                return _buildLetterCard(context, letter);
              },
            );
          }
        },
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null) {
      return '未知时间';
    }
    DateTime? dateTime = DateTime.tryParse(time);
    if (dateTime == null) {
      return '未知时间';
    }
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } catch (e) {
      return '未知时间';
    }
  }

  Widget _buildLetterCard(BuildContext context, Map<String, dynamic> letter) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final senderName = letter['is_anonymous'] == true
        ? '匿名朋友'
        : letter['sender_name']?.toString() ?? '未知发件人'; // 修改这里
    final sendTime = letter['send_time'] == null
        ? '未知时间'
        : _formatTime(letter['send_time']);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: Colors.grey[50],
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => LetterDetailScreen(
                    letter: letter, letterId: letter['id'])),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.mail_outline, size: 30, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(senderName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(
                      sendTime,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}