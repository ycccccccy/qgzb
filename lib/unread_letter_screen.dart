import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'letter_detail_screen.dart';
import 'home_screen.dart';

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
  Future<void> _updateAnonymousSetting(bool value) async {
     setState(() {
        _allowAnonymous = value;
      });
    _syncAnonymousSetting(value);
    Future.delayed(Duration(milliseconds: 100), (){
          setState(() {
             _lettersFuture = fetchUnreadLetters();
          });
    });
  }
    Future<void> _syncAnonymousSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('current_user_id') ?? '';
     try{
     await Supabase.instance.client
          .from('students')
          .update({
        'allow_anonymous': value,
      })
          .eq('student_id', currentUserId);
   await prefs.setBool('allow_anonymous', value);

      }on PostgrestException catch (e) {
         print('更新匿名信设置发生 Supabase 错误: ${e.message}');
        ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('更新失败，请稍后重试')));
          setState(() {
            _allowAnonymous = !value;
          });
      }catch(e){
          print('更新匿名信设置发生其他错误：$e');
          ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('更新失败，请稍后重试')));
             setState(() {
            _allowAnonymous = !value;
          });
      }
  }


  Future<List<Map<String, dynamic>>> fetchUnreadLetters() async {
   try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('current_user_id') ?? '';
        
        final response = await Supabase.instance.client
          .from('students')
          .select('name, class_name, allow_anonymous')
          .eq('student_id', currentUserId)
          .single();

      final studentData = response;
       final allowAnonymous = studentData['allow_anonymous'] ?? false;
      print('Current User ID: $currentUserId');

      final query = Supabase.instance.client
          .from('letters')
          .select()
          .eq('receiver_name', studentData['name'])
          .eq('receiver_class', studentData['class_name']);
         final  lettersResponse = await query;

       if(!allowAnonymous){
         return lettersResponse.where((letter) => letter['is_anonymous'] == false || letter['is_anonymous'] == null).toList();
       }else{
          return lettersResponse;
       }

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
      backgroundColor: Colors.white,
       appBar:  PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: GlobalAppBar(title: '未读信件', showBackButton: true)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('接收匿名信件', style: TextStyle(fontSize: 16, color: Colors.black87)),
                Switch(
                  value: _allowAnonymous,
                  onChanged: (value) {
                    _updateAnonymousSetting(value);
                  },
                ),
              ],
            ),
          ),
           Expanded(
             child: FutureBuilder<List<Map<String, dynamic>>>(
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
           ),
        ],
      ),
    );
  }

  Widget _buildLetterCard(BuildContext context, Map<String, dynamic> letter) {
        final isMobile = MediaQuery.of(context).size.width < 600;
         final senderId = letter['sender_id']?.toString() ?? '未知发件人';
        final sendTime = letter['send_time'] == null ? '未知时间' :  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(letter['send_time']));
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
                builder: (_) => LetterDetailScreen(letter: letter, letterId: letter['id'])),
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