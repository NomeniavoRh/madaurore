import 'package:flutter/material.dart';

class DashboardLayout extends StatelessWidget {
  final Widget content;
  final String title;
  final List<Widget>? actions;
  final Widget? drawer;
  final Widget? floatingActionButton;

  const DashboardLayout({
    Key? key,
    required this.content,
    required this.title,
    this.actions,
    this.drawer,
    this.floatingActionButton,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth < 1200;

    return Scaffold(
      appBar: isSmallScreen
          ? AppBar(title: Text(title), actions: actions)
          : null,
      drawer: isSmallScreen ? drawer : null,
      body: Row(
        children: [
          if (!isSmallScreen && drawer != null)
            SizedBox(width: 250, child: drawer!),
          Expanded(
            child: Column(
              children: [
                if (!isSmallScreen)
                  Container(
                    height: 64,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                        Spacer(),
                        if (actions != null) ...actions!,
                      ],
                    ),
                  ),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(isMediumScreen ? 16 : 24),
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
