import 'package:flutter/material.dart';

class ResponsiveList extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool isHorizontal;

  const ResponsiveList({
    super.key,
    required this.children,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    if (isHorizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: physics,
        padding: padding,
        child: Row(
          children: children
              .map(
                (child) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8.0 : 12.0,
                  ),
                  child: child,
                ),
              )
              .toList(),
        ),
      );
    }

    return ListView(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      children: children
          .map(
            (child) => Padding(
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 8.0 : 12.0,
              ),
              child: child,
            ),
          )
          .toList(),
    );
  }
}
