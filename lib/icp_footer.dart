import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class ICPFooter extends StatefulWidget {
  final String icpNumber;
  final String? icpUrl;
  
  const ICPFooter({
    Key? key, 
    required this.icpNumber,
    this.icpUrl = "https://beian.miit.gov.cn/",
  }) : super(key: key);

  @override
  State<ICPFooter> createState() => _ICPFooterState();
}

class _ICPFooterState extends State<ICPFooter> {
  bool _isVisible = false;
  final ScrollController _scrollController = ScrollController();
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    // 当滚动到底部时显示备案信息
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isVisible) {
        setState(() {
          _isVisible = true;
        });
      }
      
      // 重置隐藏计时器
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isVisible = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 在Web平台下不需要显示此组件，因为我们已经在index.html中添加了备案号
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollEndNotification) {
          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 100) {
            setState(() {
              _isVisible = true;
            });
            
            // 设置5秒后自动隐藏
            _hideTimer?.cancel();
            _hideTimer = Timer(const Duration(seconds: 5), () {
              if (mounted) {
                setState(() {
                  _isVisible = false;
                });
              }
            });
          }
        }
        return false;
      },
      child: Stack(
        children: [
          // 这是主内容区域
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: const Placeholder(), // 这里放置主内容
            ),
          ),
          
          // 备案号悬浮显示
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _isVisible ? 0 : -30,
            left: 0,
            right: 0,
            child: Container(
              height: 30,
              color: Colors.white.withOpacity(0.8),
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: widget.icpUrl != null ? () {
                  // 可以在这里实现打开浏览器访问备案链接的功能
                } : null,
                child: Text(
                  widget.icpNumber,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 轻量级包装类，可以作为Scaffold的底部组件使用
class ICPBottomSheet extends StatelessWidget {
  final String icpNumber;
  final String? icpUrl;
  
  const ICPBottomSheet({
    Key? key,
    required this.icpNumber,
    this.icpUrl,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 在Web平台下不显示，因为我们已经在index.html中处理了
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    
    return Container(
      height: 30,
      color: Colors.transparent,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        icpNumber,
        style: const TextStyle(
          color: Color(0xFF666666),
          fontSize: 12,
        ),
      ),
    );
  }
} 