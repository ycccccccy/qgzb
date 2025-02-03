import 'dart:math';
import 'package:flutter/material.dart';

class EggPage extends StatefulWidget {
  const EggPage({super.key});

  @override
  _EggPageState createState() => _EggPageState();
}

class _EggPageState extends State<EggPage> {
  final List<Star> stars = [];

  @override
  void initState() {
    super.initState();
    _generateStars();
  }

  void _generateStars() {
    final random = Random();
    for (int i = 0; i < 50; i++) {
      stars.add(Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 3 + 1,
        opacity: random.nextDouble(),
        twinkleDir: random.nextBool() ? 1 : -1,
      ));
    }
  }

  void _onTap(TapDownDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final size = MediaQuery.of(context).size;
    final x = localPosition.dx / size.width;
    final y = localPosition.dy / size.height;

    setState(() {
      stars.add(Star(
        x: x,
        y: y,
        size: 5.0, // 初始大小
        opacity: 1.0,
        twinkleDir: 1,
        isExpanding: true, // 标记为正在膨胀
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTap,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text("彩蛋", style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // 星空背景图片
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.4),
                  BlendMode.srcOver,
                ),
                child: Image.asset(
                  '../assets/images/starry_sky.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // 星星
            ...stars.map((star) => StarWidget(star: star)),
            // 文字
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final screenWidth = constraints.maxWidth;
                final baseFontSize = screenWidth * 0.035;

                return Stack(
                  children: [
                    Center(
                      child: Text(
                        "点点星光，终汇成璀璨星河",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: baseFontSize * 1.5,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 8.0,
                              color: Colors.blue.shade900,
                              offset: const Offset(3.0, 3.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: screenWidth * 0.1, // 距离底部 10% 的屏幕宽度
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Text(
                            "没有人能够熄灭满天星光",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: baseFontSize,
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          Text(
                            "每一位用户，都是我们要汇聚的星星之火",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: baseFontSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
class Star {
  double x;
  double y;
  double size;
  double opacity;
  int twinkleDir;
  bool isExpanding;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.twinkleDir,
    this.isExpanding = false,
  });
}

class StarWidget extends StatefulWidget {
  final Star star;

  const StarWidget({super.key, required this.star});

  @override
  _StarWidgetState createState() => _StarWidgetState();
}

class _StarWidgetState extends State<StarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.star.isExpanding ? 300 : 1500),
      vsync: this,
    )..repeat(reverse: !widget.star.isExpanding);

    _controller.addStatusListener((status) {
      if (widget.star.isExpanding && status == AnimationStatus.completed) {
        setState(() {
          widget.star.opacity = 0;
        });
      }
    });

    _controller.addListener(() {
      if (mounted) {
        setState(() {
          if (widget.star.isExpanding) {
            widget.star.size += 0.5;
            if (widget.star.size > 10) {
              widget.star.opacity -= 0.05;
            }
          } else {
            widget.star.opacity += 0.05 * widget.star.twinkleDir;
          }
          widget.star.opacity = widget.star.opacity.clamp(0.0, 1.0);
          if (widget.star.opacity <= 0) {
            _removeStar();
          }
        });
      }
    });
  }

  void _removeStar() {
    final _EggPageState? parentState =
        context.findAncestorStateOfType<_EggPageState>();
    if (parentState != null) {
      parentState.stars.remove(widget.star);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      left: widget.star.x * size.width,
      top: widget.star.y * size.height,
      child: Opacity(
        opacity: widget.star.opacity,
        child: Icon(
          Icons.star,
          size: widget.star.size,
          color: const Color(0xFFE0E0E0).withOpacity(widget.star.opacity),  
        ),
      ),
    );
  }
}