import 'package:flutter/material.dart';
import '../../core/constants/spacing.dart';

class DashboardLayout extends StatelessWidget {
  final Widget content;
  final String title;
  final List<Widget>? actions;
  final Widget? drawer;
  final Widget? floatingActionButton;

  const DashboardLayout({
    super.key,
    required this.content,
    required this.title,
    this.actions,
    this.drawer,
    this.floatingActionButton,
  });

  bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 650;

  bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 650 &&
      MediaQuery.of(context).size.width < 1100;

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = isMobile(context);
    final isMediumScreen = isTablet(context);

    return Scaffold(
      appBar: isSmallScreen
          ? AppBar(title: Text(title), actions: actions)
          : null,
      drawer: isSmallScreen ? drawer : null,
      body: Row(
        children: [
          if (!isSmallScreen && drawer != null)
            SizedBox(width: isMediumScreen ? 200 : 250, child: drawer!),
          Expanded(
            child: Column(
              children: [
                if (!isSmallScreen)
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.paddingSM,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 26),
                          offset: const Offset(0, 2),
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
                        const Spacer(),
                        if (actions != null) ...actions!,
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(
                      isSmallScreen ? Spacing.paddingXS : Spacing.paddingSM,
                    ),
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
