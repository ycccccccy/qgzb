import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'letter_detail_screen.dart';
import 'global_appbar.dart';
import 'api_service.dart';
import 'models.dart';

// 常量，用于保持样式一致性
const Color _primaryColor = Color(0xFF64B5F6);
const Color _textColor = Color(0xFF34495E);
const Color _greyColor = Color(0xFF718096);
const Color _backgroundColor = Color(0xFFF7FAFC);
const double _cardBorderRadius = 16.0;
const Color _whiteColor = Color(0xFFFFFFFF);
const double _horizontalPadding = 20.0;

class ReceivedLetterScreen extends StatefulWidget {
  const ReceivedLetterScreen({Key? key}) : super(key: key);

  @override
  _ReceivedLetterScreenState createState() => _ReceivedLetterScreenState();
}

class _ReceivedLetterScreenState extends State<ReceivedLetterScreen> {
  final EdgeInsets cardPadding = const EdgeInsets.all(16.0);
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _currentPage = 0;
  final int _pageSize = 10;
  List<Letter> _allLetters = [];
  bool _hasMoreData = true;
  final ApiService _apiService = ApiService();
  bool _initialLoading = true; // 新增：初始加载状态

  @override
  void initState() {
    super.initState();
    _loadLetters(); // 加载信件
    _scrollController.addListener(_scrollListener); // 添加滚动监听器
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener); // 移除滚动监听器
    _scrollController.dispose(); // 释放滚动控制器
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreLetters(); // 加载更多信件
    }
  }

  Future<void> _loadMoreLetters() async {
    if (_isLoadingMore) return; // 如果正在加载更多，则返回
    setState(() {
      _isLoadingMore = true; // 设置为正在加载更多
    });

    _currentPage++; // 页码增加
    try {
      final moreLetters = await _apiService.getReceivedLetters(
        page: _currentPage,
        pageSize: _pageSize,
      );
      if (moreLetters.isEmpty) {
        _hasMoreData = false; // 没有更多数据了
      } else {
        setState(() {
          _allLetters.addAll(moreLetters); // 将新加载的信件添加到现有列表
        });
      }
    } catch (e) {
      print('加载更多信件出错: $e'); // 打印错误信息
      _showErrorSnackBar('加载更多信件失败'); // 显示错误提示
    } finally {
      setState(() {
        _isLoadingMore = false; // 加载完成
      });
    }
  }

  Future<void> _loadLetters() async {
    _currentPage = 0; // 重置页码
    _allLetters = []; // 清空信件列表
    _hasMoreData = true; // 重置是否有更多数据标志
    _initialLoading = true; // 初始加载设为 true
    setState(() {}); // 触发 UI 重绘
    try {
      final letters = await _apiService.getReceivedLetters(
          page: _currentPage, pageSize: _pageSize);
      setState(() {
        _allLetters = letters; // 加载信件数据
      });
    } catch (e) {
      print('加载信件出错: $e'); // 打印错误信息
      _showErrorSnackBar('加载信件失败'); // 显示错误提示
    } finally {
      setState(() {
        _initialLoading = false; // 加载完成设为 false
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red, // 错误提示背景色为红色
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor, // 一致的背景颜色
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: GlobalAppBar(
            title: '收件箱', showBackButton: true, actions: []), // 使用全局 AppBar
      ),
      body: SafeArea( //  ✅  确认 SafeArea 直接包裹 Padding
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding), // 水平内边距
          child: _buildBody(), // 构建页面主体内容
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) { //  ✅  使用 _initialLoading 判断初始加载状态
      return const Center(child: CircularProgressIndicator(color: _primaryColor)); // 初始加载时显示加载指示器
    } else if (_allLetters.isEmpty) {
      return Center(
        child: Text('没有信件', style: TextStyle(color: _greyColor)), // 没有信件时显示提示信息
      );
    } else {
      return Stack(
        children: [
          ListView.separated(
            controller: _scrollController,
            padding: cardPadding,
            itemCount: _allLetters.length, // 信件列表长度
            separatorBuilder: (context, index) => const SizedBox(height: 12.0), // 列表项分隔符
            itemBuilder: (context, index) {
              final letter = _allLetters[index]; // 获取当前信件
              return _buildLetterCard(context, letter); // 构建信件卡片
            },
          ),
          if (_isLoadingMore)
            const Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator(color: _primaryColor)), // 加载更多时显示加载指示器
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
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime); // 格式化时间
    } catch (e) {
      return '未知时间';
    }
  }

  Widget _buildLetterCard(BuildContext context, Letter letter) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final senderName =
        letter.isAnonymous == 'true' ? '匿名朋友' : letter.senderName ?? '未知发件人'; // 发件人姓名，匿名信件显示“匿名朋友”
    final sendTime = _formatTime(letter.sendTime); // 格式化发送时间

    return Card(
      elevation: 2, // 增加阴影
      shadowColor: Colors.black12, // 柔和的阴影颜色
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardBorderRadius), // 圆角边框
      ),
      color: _whiteColor, // 白色卡片背景
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  LetterDetailScreen(letterId: letter.id!), // 跳转到信件详情页，传递 letterId
            ),
          );
        },
        borderRadius: BorderRadius.circular(_cardBorderRadius), // InkWell 圆角
        child: Padding(
          padding: cardPadding,
          child: Row(
            children: [
              Icon(Icons.mail_outline, size: 30, color: _primaryColor), // 邮件图标，使用主题色
              const SizedBox(width: 16), // 增加水平间距
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(senderName,
                        style: const TextStyle(
                            fontSize: 18, // 稍微增大字体
                            fontWeight: FontWeight.w500,
                            color: _textColor, // 使用主题文本颜色
                            fontFamily: 'Montserrat')), // 使用 Montserrat 字体
                    const SizedBox(height: 6), // 增加垂直间距
                    Text(
                      sendTime,
                      style: TextStyle(fontSize: 15, color: _greyColor), // 时间信息使用灰色
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Icon(Icons.arrow_forward_ios, size: 16, color: _greyColor.withOpacity(0.6)), // 箭头图标，灰色
            ],
          ),
        ),
      ),
    );
  }
}