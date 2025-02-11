import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'letter_detail_screen.dart'; // 确保这个文件存在
import 'global_appbar.dart';
import 'api_service.dart'; // 导入 ApiService
import 'models.dart'; // 导入 Letter 模型

class ReceivedLetterScreen extends StatefulWidget {
  const ReceivedLetterScreen({Key? key}) : super(key: key);

  @override
  _ReceivedLetterScreenState createState() => _ReceivedLetterScreenState();
}

class _ReceivedLetterScreenState extends State<ReceivedLetterScreen> {
  final Color cardColor = Colors.grey[50]!;
  final EdgeInsets cardPadding = const EdgeInsets.all(16.0);
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _currentPage = 0;
  final int _pageSize = 10;
  List<Letter> _allLetters = []; // 改为 List<Letter>
  bool _hasMoreData = true;
  final _apiService = ApiService(); // 实例化 ApiService

    @override
  void initState() {
    super.initState();
     _loadLetters(); // 初始加载
    _scrollController.addListener(_scrollListener); // 添加滚动监听器
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
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreLetters();
    }
  }

   Future<void> _loadMoreLetters() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++; // 增加页码
    try {
      final moreLetters = await _apiService.getReceivedLetters(
        page: _currentPage,
        pageSize: _pageSize,
      );
       if (moreLetters.isEmpty) {
        _hasMoreData = false; // 没有更多数据
      } else {
        setState(() {
          _allLetters.addAll(moreLetters);
        });
      }

    } catch (e) {
       print('加载更多信件出错: $e');
      _showErrorSnackBar('加载更多信件失败'); // 显示错误
    } finally {
       setState(() {
        _isLoadingMore = false; // 加载完成
      });
    }

  }
  //改为 Future<void>
    Future<void> _loadLetters() async {
    _currentPage = 0; // 重置页码
    _allLetters = []; // 清空列表
    _hasMoreData = true; //重置
    setState(() {}); // 触发 UI 重绘
     try {
        final letters = await _apiService.getReceivedLetters(page: _currentPage, pageSize: _pageSize);
        setState(() {
          _allLetters = letters;
        });
      } catch (e) {
         print('加载信件出错: $e');
        _showErrorSnackBar('加载信件失败');
      }
  }


  void _showErrorSnackBar(String message) {
    if (mounted) {
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: GlobalAppBar(title: '收件箱', showBackButton: true, actions: [])),
      body:  _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_allLetters.isEmpty && _hasMoreData) {
          return const Center(child: CircularProgressIndicator()); // 初始加载时显示
    } else if (_allLetters.isEmpty) {
      return Center(
          child: Text('没有信件', style: TextStyle(color: Colors.grey[500])));
    } else {
       return Stack(
        children: [
          ListView.separated(
            controller: _scrollController,
            padding: cardPadding,
            itemCount: _allLetters.length, // 使用 Letter 对象的列表
            separatorBuilder: (context, index) => const SizedBox(height: 8.0),
            itemBuilder: (context, index) {
              final letter = _allLetters[index];
              return _buildLetterCard(context, letter); // 传入 Letter 对象
            },
          ),
          if (_isLoadingMore)
            const Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
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
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } catch (e) {
      return '未知时间';
    }
  }

Widget _buildLetterCard(BuildContext context, Letter letter) {
  final isMobile = MediaQuery.of(context).size.width < 600;
  final senderName =
      letter.isAnonymous == 'true' ? '匿名朋友' : letter.senderName ?? '未知发件人';
  final sendTime = _formatTime(letter.sendTime);

  return Card(
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    color: cardColor,
    child: InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LetterDetailScreen(letterId: letter.id!), //  <--  只传递 letterId
          ),
        );
      },
      child: Padding(
        padding: cardPadding,
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
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey),
          ],
        ),
      ),
    ),
  );
}
}