import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'global_appbar.dart';
import 'settings_screen.dart';
import 'contact_us_screen.dart';
import 'login_screen.dart';
import 'time_capsule_home.dart'; // 导入新的页面

// 常量定义
const double _buttonSpacing = 20.0;
const double _iconSize = 60.0;
const double _borderRadius = 10.0;
const Color _textColor = Color(0xFF333333); // 深灰色
const Color _greyColor = Color(0xFF888888); // 浅灰色
const Color _whiteColor = Colors.white;
const Color _backgroundGrey = Color(0xFFF5F5F5); // 浅灰色背景
const double _buttonPadding = 16.0;
const Color _primaryColor = Color(0xFF4A90E2); // 主题色，例如蓝色
const double _cardElevation = 2.0; // 卡片阴影高度

bool flg = false; // 全局变量，控制是否已登录, 放到文件开头

class HomeScreenMain extends StatefulWidget {
  const HomeScreenMain({super.key});

  @override
  _HomeScreenMainState createState() => _HomeScreenMainState();
}

class _HomeScreenMainState extends State<HomeScreenMain> {
  int _selectedIndex = 0; // 当前选中的菜单项
  String _notificationText = '欢迎使用，开启你的跨校沟通之旅吧！'; // 通知文本

  @override
  void initState() {
    super.initState();
    _loadNotificationText(); // 加载通知文本
    _checkFirstLaunch(); // 检查是否首次启动
  }

  // 加载通知文本
  Future<void> _loadNotificationText() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationText = prefs.getString('notificationText') ??
        '公告：欢迎来到鸿雁心笺，一个连接心灵、珍藏记忆的温暖角落。在这里，我们为你精心准备了两项特色功能：“写封信给Ta”与“时空胶囊”。\n通过信件，你可以轻松互送节日祝福，传递温馨寄语，让心意在指尖流转，无论距离多远，都能感受到彼此的关怀与祝福。\n而时空胶囊则为即将毕业的学子们提供了一个独特的机会，封存青春絮语，静待考试落幕，让回忆在时光中重现。无论是此刻的梦想、希望还是对未来的憧憬，都可以在这里安全保存，待到金榜题名时，重启那些珍贵的瞬间。\n鸿雁心笺是你传递情感、珍藏记忆的温馨港湾。在这里，每一份祝福都被珍视，每一段回忆都被妥善保存。';
    setState(() {
      _notificationText = notificationText;
    });
  }

  // 检查是否首次启动
  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirst = prefs.getBool('isFirstLaunch') ?? true;
    if (isFirst) {
      _showWelcomeDialog(); // 显示欢迎对话框
      await prefs.setBool('isFirstLaunch', false); // 设置为非首次启动
    }
    setState(() {});
  }

  // 显示欢迎对话框
  void _showWelcomeDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('欢迎使用'),
            content: const Text('欢迎来到鸿雁心笺！\n在这里你可以与远方的朋友们交流，传递心意。'),
            actions: <Widget>[
              TextButton(
                child: const Text('开始体验'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600; // 判断是否为手机
    return Scaffold(
      backgroundColor: _backgroundGrey,
      extendBodyBehindAppBar: true, // 扩展 body 到 AppBar 后面
      appBar: null, // 不使用默认 AppBar
      drawer: _buildDrawer(context), // 侧边栏
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 32),
          child: Column(
            children: [
              const GlobalAppBar(
                title: '主页',
                showBackButton: false,
                actions: [],
              ), // 自定义 AppBar
              _buildNotificationCard(context), // 通知卡片
              Expanded(child: _buildMainContent(context)), // 主界面内容
            ],
          ),
        ),
      ),
    );
  }

  // 构建通知卡片
  Widget _buildNotificationCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        elevation: _cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
        child: InkWell(
          onTap: () {
            _showFullNotificationDialog(context); // 显示完整通知
          },
          borderRadius: BorderRadius.circular(_borderRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _notificationText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }

  // 显示完整通知对话框
  void _showFullNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('通知'),
          content: Text(_notificationText),
          actions: <Widget>[
            TextButton(
              child: const Text('知道了'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // 构建侧边栏
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: _whiteColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
              child: Text('菜单',
                  style: TextStyle(fontSize: 24, color: _textColor)),
            ),
            ListTile(
              leading:
                  const Icon(Icons.home, color: _textColor, semanticLabel: "主页"),
              title: const Text('主页', style: TextStyle(color: _textColor)),
              selected: _selectedIndex == 0,
              selectedTileColor: _primaryColor.withOpacity(0.1),
              onTap: () {
                _updateSelectedIndex(0); // 更新选中项
                Navigator.pop(context); // 关闭侧边栏
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings,
                  color: _textColor, semanticLabel: "设置"),
              title: const Text('设置', style: TextStyle(color: _textColor)),
              selected: _selectedIndex == 1,
              selectedTileColor: _primaryColor.withOpacity(0.1),
              onTap: () {
                _updateSelectedIndex(1);
                Navigator.push(context,
                    _createPageRoute(() => const SettingsScreen())); // 导航到设置页
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline,
                  color: _textColor, semanticLabel: "关于我们"),
              title: const Text('关于我们', style: TextStyle(color: _textColor)),
              selected: _selectedIndex == 2,
              selectedTileColor: _primaryColor.withOpacity(0.1),
              onTap: () {
                _updateSelectedIndex(2);
                Navigator.push(context,
                    _createPageRoute(() => const ContactUsScreen())); // 导航到关于我们页
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.logout, color: _textColor, semanticLabel: "登出"),
              title: const Text('登出', style: TextStyle(color: _textColor)),
              selected: _selectedIndex == 3,
              selectedTileColor: _primaryColor.withOpacity(0.1),
              onTap: () {
                _updateSelectedIndex(3);

                // 退出登录，重置 flg
                flg = false;

                // 清除自动登录状态, 传入 key
                _clearSharedPreferencesValue('autoLogin');

                // 使用 pushReplacement，避免用户通过返回键回到主页
                Navigator.pushReplacement(
                  context,
                  _createPageRoute(() => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 通用的清除 SharedPreferences 值的方法
  Future<void> _clearSharedPreferencesValue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // 更新选中项
  void _updateSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 构建主界面内容
  Widget _buildMainContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600; // 再次判断是否为手机
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Expanded(
            child: _buildButtons(context), // 构建按钮
          ),
        ],
      ),
    );
  }

  // 构建按钮
  Widget _buildButtons(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: _buttonSpacing,
        runSpacing: _buttonSpacing,
        children: [
          SizedBox(
            width: 280,
            child: CustomButton(
              imagePath: 'assets/images/custom_icon1.png', // 图片路径
              topText: '写封信给Ta',
              bottomText: '落笔不问来处\n墨痕自渡山海',
              dialogTitle: '', // 不需要弹窗，设置为空
              dialogContent: '', // 不需要弹窗，设置为空
              onPressed: () {
                Navigator.push(
                    context, _createPageRoute(() => const HomeScreen())); // 导航到写信页
              },
            ),
          ),
          SizedBox(
            width: 280,
            child: CustomButton(
              imagePath: 'assets/images/custom_icon2.png', // 图片路径
              topText: '时空胶囊',
              bottomText: '此刻指尖轻点，封存青春絮语\n待金榜题名时，重启时光密语',
              showDialog: true, // 需要显示确认对话框
              dialogTitle: '确认跳转',
              dialogContent: '此功能仅限初三、高三学生使用',
              onPressed: () {
                _showConfirmDialog(context, '确认跳转',
                    '此功能仅限初三、高三学生使用', () {
                  Navigator.push(context,
                      _createPageRoute(() => const TimeCapsuleHome())); // 导航到时空胶囊页
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // 创建页面路由（带动画）
  PageRouteBuilder _createPageRoute(Widget Function() builder) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => builder(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }
}

// 自定义按钮组件
class CustomButton extends StatelessWidget {
  final String? imagePath; // 图片路径
  final IconData? iconData; // 图标数据，与 imagePath 二选一
  final String topText; // 上方文本
  final String bottomText; // 下方文本
  final VoidCallback onPressed; // 点击事件
  final bool showDialog; // 是否显示对话框
  final String dialogTitle; // 对话框标题
  final String dialogContent; // 对话框内容

  const CustomButton({
    super.key,
    this.imagePath,
    this.iconData,
    required this.topText,
    required this.bottomText,
    required this.onPressed,
    this.showDialog = false,
    this.dialogTitle = '',
    this.dialogContent = '',
  }) : assert(imagePath != null || iconData != null,
            '必须提供 imagePath 或 iconData 中的一个');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: _cardElevation,
      shadowColor: _greyColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      child: Ink(
        decoration: BoxDecoration(
          color: _whiteColor,
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
        child: InkWell(
          onTap: () {
            if (showDialog) {
              onPressed(); // 如果需要显示对话框，直接执行 onPressed
            } else {
              onPressed(); // 如果不需要显示对话框，直接执行 onPressed
            }
          },
          borderRadius: BorderRadius.circular(_borderRadius),
          child: Padding(
            padding: const EdgeInsets.all(_buttonPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (imagePath != null) // 如果有图片，显示图片
                  Image.asset(
                    imagePath!,
                    width: _iconSize,
                    height: _iconSize,
                  ),
                if (iconData != null) // 如果有图标，显示图标
                  Icon(
                    iconData,
                    size: _iconSize,
                    color: _textColor,
                  ),
                const SizedBox(height: 8.0),
                Text(
                  topText,
                  style: const TextStyle(
                      fontSize: 16.0,
                      color: _textColor,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4.0),
                Text(
                  bottomText,
                  style: const TextStyle(fontSize: 14.0, color: _greyColor),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 显示确认对话框
void _showConfirmDialog(
    BuildContext context, String title, String content, VoidCallback onConfirm) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('确认'),
            onPressed: () {
              Navigator.of(context).pop(); // 关闭对话框
              onConfirm(); // 执行确认操作
            },
          ),
        ],
      );
    },
  );
}