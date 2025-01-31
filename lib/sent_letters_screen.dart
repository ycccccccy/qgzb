import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'letter_detail_screen.dart';
import 'package:intl/intl.dart';

class SentLettersScreen extends StatefulWidget {
  const SentLettersScreen({super.key});

  @override
  _SentLettersScreenState createState() => _SentLettersScreenState();
}

class _SentLettersScreenState extends State<SentLettersScreen> {
  late Future<List<Map<String, dynamic>>> _lettersFuture;

  @override
  void initState() {
    _lettersFuture = _fetchSentLetters();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
       appBar:  PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: GlobalAppBar(title: '已发送信件', showBackButton: true)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _lettersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Error', style: TextStyle(color: Colors.red)));
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final letter = snapshot.data![index];
                return Card(
                    elevation: 1,
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    color: Colors.grey[50],
                    child: InkWell(
                      onTap: (){
                        Navigator.push(context, MaterialPageRoute(builder: (_) =>  LetterDetailScreen(letter: letter, letterId: letter['id'])));
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('收件人: ${letter['receiver_name']}',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[700])),
                            const SizedBox(height: 4),
                              Text(
                                letter['send_time'] == null ? '未知时间' :  '${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(letter['send_time']))}',
                                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                              ),
                            Text('信件内容: ${letter['content']}',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[500]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis)
                          ],
                        ),
                      ),
                    ));
              },
            );
          } else {
            return const Center(
                child: Text('无已发送信件', style: TextStyle(color: Colors.grey)));
          }
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchSentLetters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('current_user_id') ?? '';

      final response = await Supabase.instance.client
          .from('letters')
          .select()
          .eq('sender_id', currentUserId);
      return response;
    } on PostgrestException catch (e) {
      print('获取已发送信件发生 Supabase 错误: ${e.message}');
      return [];
    } catch (e) {
      print('获取已发送信件发生其他错误：$e');
      return [];
    }
  }
}