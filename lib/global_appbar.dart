import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget> actions;

  const GlobalAppBar({
    Key? key,
    required this.title,
    this.showBackButton = false,
    this.actions = const <Widget>[],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false, 
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: showBackButton
            ? IconButton(
                icon:
                    const Icon(Icons.arrow_back, size: 30, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu, size: 30, color: Colors.black87),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: actions,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight); // 使用标准高度
}