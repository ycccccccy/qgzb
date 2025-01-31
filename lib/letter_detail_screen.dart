import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class LetterDetailScreen extends StatefulWidget {
  final int letterId;
  LetterDetailScreen({required this.letterId, required Map<String, dynamic> letter});
  @override
  _LetterDetailScreenState createState() => _LetterDetailScreenState();
}

class _LetterDetailScreenState extends State<LetterDetailScreen> {
  late Future<Map<String, dynamic>?> _letterFuture;

    @override
  void initState() {
      super.initState();
      _letterFuture = fetchLetterDetails(widget.letterId);
  }

  Future<Map<String, dynamic>?> fetchLetterDetails(int letterId) async {
    try {
      final response = await Supabase.instance.client
          .from('letters')
          .select()
          .eq('id', letterId)
          .single();
      return response;
    } on PostgrestException catch (e) {
      print('获取信件详情发生 Supabase 错误: ${e.message}');
      return null;
    } catch (e) {
      print('获取信件详情发生其他错误：$e');
       return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
     return Scaffold(
      backgroundColor: Colors.white,
       appBar:  PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: GlobalAppBar(title: '信件详情', showBackButton: true)),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _letterFuture,
         builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) {
             return Center(child: CircularProgressIndicator());
           } else if (snapshot.hasError || snapshot.data == null ) {
             return Center(child: Text('加载失败',  style: TextStyle(color: Colors.red)));
           }else{
               final letter = snapshot.data!;
               return Padding(
                   padding: EdgeInsets.all(isMobile ? 16 : 32),
                    child: SingleChildScrollView(
                     child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                   Text(
                                      letter['sender_id']?.toString()?? '未知发件人',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                   ),
                                     Text(
                                       letter['send_time'] == null ? '未知时间' :  '${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(letter['send_time']))}',
                                 style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                             ),
                              ],
                             ),
                          SizedBox(height: 16),
                          Text(
                            '收件人:',
                            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                          ),
                          Text(
                              letter['receiver_name']?.toString()?? '未知收件人',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
                          ),
                           SizedBox(height: 16),
                           Text(
                             '内容:',
                             style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                           ),
                          SizedBox(height: 8),
                           Text(
                             letter['content']?.toString()?? '',
                             style: TextStyle(fontSize: 16, color: Colors.black87),
                            ),
                        ],
                     ),
                    ),
                );
           }
        },
      ),
    );
  }
}