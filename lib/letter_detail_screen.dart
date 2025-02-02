import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'global_appbar.dart';

class LetterDetailScreen extends StatelessWidget {
  final int letterId;
  final Map<String, dynamic> letter;
   LetterDetailScreen({super.key, required this.letterId, required this.letter});
   final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
   final String _unknownSender = '未知发件人';
   final String _unknownSchool = '未知学校';
   final String _unknownReceiver = '未知收件人';
   final String _senderSchoolTitle = '发件人学校:';
   final String _receiverSchoolTitle = '收件人学校:';
   final String _receiverTitle = '收件人:';
  final String _contentTitle = '内容:';

  String _formatTime(String? time) {
    if (time == null) {
      return '未知时间';
    }
    DateTime? dateTime = DateTime.tryParse(time);
    if (dateTime == null) {
      return '未知时间';
    }
    try {
      return _dateFormat.format(dateTime);
    } catch (e) {
      return '未知时间';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final senderName = letter['is_anonymous'] == true
        ? '匿名朋友'
        : letter['sender_name']?.toString() ?? _unknownSender;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: GlobalAppBar(title: '信件详情', showBackButton: true, actions: [],)),
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
                    _formatTime(letter['send_time']),
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _senderSchoolTitle,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                letter['my_school']?.toString() ?? _unknownSchool,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Text(
               _receiverSchoolTitle,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                 letter['target_school']?.toString() ?? _unknownSchool,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Text(
                _receiverTitle,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                letter['receiver_name']?.toString() ?? _unknownReceiver,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Text(
               _contentTitle,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                letter['content']?.toString() ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}