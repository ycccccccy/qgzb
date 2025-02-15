import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'global_appbar.dart';
import 'api_service.dart';
import 'models.dart';
import 'letter_detail_screen.dart';

class SentLettersScreen extends StatefulWidget {
  const SentLettersScreen({Key? key}) : super(key: key);

  @override
  _SentLettersScreenState createState() => _SentLettersScreenState();
}

class _SentLettersScreenState extends State<SentLettersScreen> {
  final Color _backgroundColor = const Color(0xFFF7FAFC); // 浅蓝灰色背景, 和HomeScreen一致
  final Color _cardColor = Colors.white; // 白色卡片
  final EdgeInsets _cardMargin =
      const EdgeInsets.symmetric(vertical: 8, horizontal: 16);
  final double _cardBorderRadius = 16.0; // 圆角
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _currentPage = 0;
  final int _pageSize = 10;
  List<Letter> _allLetters = [];
  bool _hasMoreData = true;
  bool _isInitialLoading = true;
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadLetters();
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
      _isInitialLoading = true;
    });

    try {
      final letters = await _apiService.getSentLetters(
          page: _currentPage, pageSize: _pageSize);
      setState(() {
        _allLetters = letters;
        _isInitialLoading = false;
      });
    } catch (e) {
      print('加载信件出错: $e');
      _showErrorSnackBar('加载信件失败');
      setState(() {
        _isInitialLoading = false;
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
      backgroundColor: _backgroundColor, // 使用统一的背景色
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: GlobalAppBar(title: '已发送信件', showBackButton: true, actions: []),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_allLetters.isEmpty) {
      return Center(
          child: Text('无已发送信件',
              style: TextStyle(color: Colors.grey[600]))); // 优化空状态文本颜色
    } else {
      return Stack(
        children: [
          ListView.separated(
            controller: _scrollController,
            itemCount: _allLetters.length,
            padding: const EdgeInsets.only(
                top: 16, bottom: 16), // 为列表添加上下内边距，避免遮挡
            separatorBuilder: (context, index) =>
                const SizedBox(height: 8.0), // 可以适当调整间距
            itemBuilder: (context, index) {
              final letter = _allLetters[index];
              final formattedTime = _formatTime(letter.sendTime);
              return _buildLetterCard(context, letter, formattedTime);
            },
          ),
          if (_isLoadingMore)
            Positioned(
              bottom: 16, // 调整加载指示器的位置
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8.0), // 添加内边距
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8), // 半透明背景
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      );
    }
  }

  Widget _buildLetterCard(
      BuildContext context, Letter letter, String formattedTime) {
    return Card(
      elevation: 1.5, // 增加轻微阴影
      shadowColor: Colors.black.withOpacity(0.5), //更淡的阴影
      margin: _cardMargin,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardBorderRadius)),
      color: _cardColor,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  LetterDetailScreen(letterId: letter.id!), // 修正导航
            ),
          );
        },
        borderRadius:
            BorderRadius.circular(_cardBorderRadius), // 保持 InkWell 的圆角
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '收件人: ${letter.receiverName}',
                style: const TextStyle(
                    fontSize: 17, // 增大字号
                    fontWeight: FontWeight.w600, // 使用半粗体
                    color: Color(0xFF34495E)),
              ),
              const SizedBox(height: 4),
              Text(
                formattedTime,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]), // 加深颜色
              ),
              const SizedBox(height: 8), // 增加间距
              Text(letter.content,
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)
            ],
          ),
        ),
      ),
    );
  }
}