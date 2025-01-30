import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'letter_detail_screen.dart';

class UnreadLetterScreen extends StatefulWidget {
  @override
  _UnreadLetterScreenState createState() => _UnreadLetterScreenState();
}

class _UnreadLetterScreenState extends State<UnreadLetterScreen> {
  late Future<List<Map<String, dynamic>>> _lettersFuture;

  @override
  void initState() {
    super.initState();
    _lettersFuture = fetchUnreadLetters();
  }

  Future<List<Map<String, dynamic>>> fetchUnreadLetters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('current_user_id') ?? '';
        
        final response = await Supabase.instance.client
          .from('students')
          .select('name, class_name')
          .eq('student_id', currentUserId)
          .single();

      final studentData = response;
      print('Current User ID: $currentUserId');

      final lettersResponse = await Supabase.instance.client
          .from('letters')
          .select()
          .eq('receiver_name', studentData['name'])
          .eq('receiver_class', studentData['class_name']);

      print('Supabase Response: $lettersResponse');

      return lettersResponse;
    } on PostgrestException catch (e) {
      print('获取信件数据发生 Supabase 错误: ${e.message}');
      return [];
    } catch (e) {
      print('获取信件数据发生其他错误：$e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('未读信件', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        elevation: 1,
      ),
      backgroundColor: Colors.white, 
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _lettersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('Loading...');
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
             print('Error: ${snapshot.error}');
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: TextStyle(color: Colors.red)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
             print('No data');
            return Center(
                child: Text('没有未读信件',
                    style: TextStyle(color: Colors.grey[500])));
          } else {
              print('Data received: ${snapshot.data}');
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

  Widget _buildLetterCard(BuildContext context, Map<String, dynamic> letter) {
        final isMobile = MediaQuery.of(context).size.width < 600;
         final senderId = letter['sender_id']?.toString() ?? '未知发件人';
        final createdAt = letter['created_at'] == null ? '未知时间' :  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(letter['created_at']));
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
                builder: (_) => LetterDetailScreen(letterId: letter['id'])),
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
                            Text(senderId,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                 color: Colors.black87)),
                                 const SizedBox(height: 4),
                                Text(
                                   createdAt,
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