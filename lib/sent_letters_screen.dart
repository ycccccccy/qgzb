import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'letter_detail_screen.dart';
import 'package:intl/intl.dart';
import 'global_appbar.dart';

class SentLettersScreen extends StatefulWidget {
  const SentLettersScreen({super.key});

  @override
  _SentLettersScreenState createState() => _SentLettersScreenState();
}

class _SentLettersScreenState extends State<SentLettersScreen> {
  late Future<List<Map<String, dynamic>>> _lettersFuture;
  final Color backgroundColor = Colors.grey[100]!;
  final Color cardColor = Colors.grey[50]!;
  final EdgeInsets cardMargin =
  const EdgeInsets.symmetric(vertical: 8, horizontal: 16);
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _currentPage = 0;
  final int _pageSize = 10;
  List<Map<String, dynamic>> _allLetters = [];
  bool _hasMoreData = true;


  @override
  void initState() {
    super.initState();
    _lettersFuture = _loadLetters();
    _scrollController.addListener(_scrollListener);
  }
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent &&
        !_isLoadingMore && _hasMoreData) {
      _loadMoreLetters();
    }
  }
  Future<void> _loadMoreLetters() async{
    if(_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    _currentPage++;
    final moreLetters = await fetchSentLetters();
    if (moreLetters.isEmpty) {
      setState(() {
        _hasMoreData = false;
      });
    } else {
      setState(() {
        _allLetters.addAll(moreLetters);
      });
    }
    setState(() {
      _isLoadingMore = false;
    });
  }

  Future<List<Map<String, dynamic>>> _loadLetters() async {
    _currentPage = 0;
    _allLetters = [];
    setState(() {

    });
    final letters = await fetchSentLetters();
    setState(() {
      _allLetters = letters;
    });
    return letters;
  }


  Future<List<Map<String, dynamic>>> fetchSentLetters() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id; // 修改：使用 Supabase Auth 获取 currentUserId
      if (currentUserId == null) {
        _showErrorSnackBar('用户未登录，无法加载已发送信件'); // 添加用户未登录提示
        return [];
      }

      final response = await Supabase.instance.client
          .from('letters')
          .select()
          .eq('sender_id', currentUserId)
          .range(_currentPage * _pageSize, (_currentPage + 1) * _pageSize -1); 

      return (response as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? []; // 类型转换和空值处理
    } on PostgrestException catch (e) {
      _showErrorSnackBar('获取已发送信件发生 Supabase 错误: ${e.message}');
      return [];
    } catch (e) {
      _showErrorSnackBar('获取已发送信件发生其他错误：$e');
      return [];
    }
  }
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: GlobalAppBar(
              title: '已发送信件', showBackButton: true, actions: [])),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _lettersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(
              child: Text('Error', style: TextStyle(color: Colors.red)));
        } else if (_allLetters.isNotEmpty) {
          return Stack(
            children: [
              ListView.separated(
                controller: _scrollController,
                itemCount: _allLetters.length,
                separatorBuilder: (context, index) =>
                const SizedBox(height: 8.0),
                itemBuilder: (context, index) {
                  final letter = _allLetters[index];
                  final formattedTime = _formatTime(letter['send_time']);
                  return _buildLetterCard(context, letter, formattedTime);
                },
              ),
              if(_isLoadingMore)
                const Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Center(child: CircularProgressIndicator())
                )
            ],
          );
        } else {
          return const Center(
              child: Text('无已发送信件', style: TextStyle(color: Colors.grey)));
        }
      },
    );
  }

  Widget _buildLetterCard(
      BuildContext context, Map<String, dynamic> letter, String formattedTime) {
    return Card(
      elevation: 1,
      margin: cardMargin,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: cardColor,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LetterDetailScreen(
                  letter: letter, letterId: letter['id']),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('收件人: ${letter['receiver_name']}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              const SizedBox(height: 4),
              Text(
                formattedTime,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              Text('信件内容: ${letter['content']}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)
            ],
          ),
        ),
      ),
    );
  }
}