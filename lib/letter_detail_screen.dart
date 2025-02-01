import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'global_appbar.dart';

class LetterDetailScreen extends StatefulWidget {
  final int letterId;
  final Map<String, dynamic> letter;
  LetterDetailScreen({required this.letterId, required this.letter});
  @override
  _LetterDetailScreenState createState() => _LetterDetailScreenState();
}

class _LetterDetailScreenState extends State<LetterDetailScreen> {
  late Map<String, dynamic> _letter;
  @override
  void initState() {
    super.initState();
    _letter = widget.letter;
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
      final senderName = _letter['is_anonymous'] == true
          ? '匿名朋友'
          : _letter['sender_name']?.toString() ?? '未知发件人';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: GlobalAppBar(title: '信件详情', showBackButton: true)),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                   senderName,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  Text(
                    _formatTime(_letter['send_time']),
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '发件人学校:',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                _letter['my_school']?.toString() ?? '未知学校',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Text(
                '收件人学校:',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                _letter['target_school']?.toString() ?? '未知学校',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Text(
                '收件人:',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                _letter['receiver_name']?.toString() ?? '未知收件人',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Text(
                '内容:',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                _letter['content']?.toString() ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}