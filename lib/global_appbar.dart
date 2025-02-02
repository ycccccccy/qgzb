import 'package:flutter/material.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  const GlobalAppBar({super.key, required this.title, this.showBackButton = false, required List<IconButton> actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        showBackButton ? IconButton(
          icon: const Icon(Icons.arrow_back, size: 30, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ) : IconButton(
          icon: const Icon(Icons.menu, size: 30, color: Colors.black87),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}