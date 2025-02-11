import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'global_appbar.dart';
import 'api_service.dart'; // 导入 ApiService
import 'models.dart'; // 导入 Letter 模型
import 'letter_detail_screen.dart'; // 导入 LetterDetailScreen

class SentLettersScreen extends StatefulWidget {
  const SentLettersScreen({Key? key}) : super(key: key);

  @override
  _SentLettersScreenState createState() => _SentLettersScreenState();
}

class _SentLettersScreenState extends State<SentLettersScreen> {
  final Color backgroundColor = Colors.grey[100]!;
  final Color cardColor = Colors.grey[50]!;
  final EdgeInsets cardMargin =
      const EdgeInsets.symmetric(vertical: 8, horizontal: 16);
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _currentPage = 0;
  final int _pageSize = 10;
  List<Letter> _allLetters = []; // 改为 List<Letter>
  bool _hasMoreData = true;
  bool _isInitialLoading = true; // 添加这个标志
  final _apiService = ApiService(); // 实例化 ApiService

  @override
  void initState() {
    super.initState();
    _loadLetters(); // 初始加载
    _scrollController.addListener(_scrollListener); // 添加滚动监听
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

    _currentPage++;
    try {
      final moreLetters = await _apiService.getSentLetters(
        page: _currentPage,
        pageSize: _pageSize,
      );
      if (moreLetters.isEmpty) {
        _hasMoreData = false;
      } else {
        setState(() {
          _allLetters.addAll(moreLetters);
        });
      }
    } catch (e) {
      print('加载更多信件出错: $e');
      _showErrorSnackBar('加载更多信件失败');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadLetters() async {
      _currentPage = 0;
      _allLetters = [];
      _hasMoreData = true;
      setState(() {
        _isInitialLoading = true; // 开始初始加载
      });

      try {
        final letters = await _apiService.getSentLetters(
            page: _currentPage, pageSize: _pageSize);
        setState(() {
          _allLetters = letters;
          _isInitialLoading = false; // 加载完成
        });
      } catch (e) {
        print('加载信件出错: $e');
        _showErrorSnackBar('加载信件失败');
        setState(() {
          _isInitialLoading = false; // 加载出错，也算完成
        });
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
        child: GlobalAppBar(title: '已发送信件', showBackButton: true, actions: []),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
      if (_isInitialLoading) {
        return const Center(child: CircularProgressIndicator()); // 初始加载状态
      } else if (_allLetters.isEmpty) {
        return Center(
            child: Text('无已发送信件', style: TextStyle(color: Colors.grey[500]))); // 空数据状态
      } else {
        return Stack(
          children: [
            ListView.separated(
              controller: _scrollController,
              itemCount: _allLetters.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8.0),
              itemBuilder: (context, index) {
                final letter = _allLetters[index];
                final formattedTime = _formatTime(letter.sendTime);
                return _buildLetterCard(context, letter, formattedTime);
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

    Widget _buildLetterCard(
      BuildContext context, Letter letter, String formattedTime) {
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
              builder: (_) => LetterDetailScreen(letterId: letter.id!),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('收件人: ${letter.receiverName}', // 使用 letter.receiverName
                  style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              const SizedBox(height: 4),
              Text(
                formattedTime,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              Text('信件内容: ${letter.content}', // 使用 letter.content
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