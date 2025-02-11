import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'global_appbar.dart';
import 'api_service.dart'; // 导入 ApiService
import 'models.dart';      // 导入 Letter 模型

class LetterDetailScreen extends StatefulWidget {
  final String letterId;

  const LetterDetailScreen({Key? key, required this.letterId})
      : super(key: key);

  @override
  _LetterDetailScreenState createState() => _LetterDetailScreenState();
}

class _LetterDetailScreenState extends State<LetterDetailScreen> {
  Letter? _letter; // 使用 Letter? 类型
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final String _unknownSender = '未知发件人';
  final String _senderSchoolTitle = '发件人学校:';
  final String _receiverSchoolTitle = '收件人学校:';
  final String _receiverTitle = '收件人:';
  final String _contentTitle = '内容:';
    final _apiService = ApiService(); // 实例化 ApiService
  bool _isLoading = true;


    @override
  void initState() {
    super.initState();
    _loadLetterDetails(); // 直接加载信件详情
  }


  Future<void> _loadLetterDetails() async {
   try {
      final letter = await _apiService.getLetterById(widget.letterId);
      setState(() {
        _letter = letter;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('获取信件详情失败');
       setState(() {
        _isLoading = false; // 即使出错也要停止加载
      });
    }
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
      return _dateFormat.format(dateTime);
    } catch (e) {
      return '未知时间';
    }
  }

  void _showErrorSnackBar(String message) {
    if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

@override
Widget build(BuildContext context) {
  final isMobile = MediaQuery.of(context).size.width < 600;

  // 如果 _letter 为 null (还在加载或出错), 显示加载指示器或错误信息
  if (_isLoading) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  if (_letter == null) {
    return const Scaffold(
      body: Center(child: Text('加载信件失败')),
    );
  }
  final senderName = _letter!.isAnonymous == 'true'  //直接访问
      ? '匿名朋友'
      : _letter!.senderName ?? _unknownSender;

  return Scaffold(
    backgroundColor: Colors.white,
    appBar: const PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: GlobalAppBar(title: '信件详情', showBackButton: true, actions: []),
    ),
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
                    color: Colors.black87,
                  ),
                ),
                Text(
                  _formatTime(_letter!.sendTime),//直接访问
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
              _letter!.mySchool, //直接访问
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _receiverSchoolTitle,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            Text(
              _letter!.targetSchool, //直接访问
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _receiverTitle,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            Text(
              _letter!.receiverName, //直接访问
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _contentTitle,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              _letter!.content ,//直接访问
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    ),
  );
}
}