import 'package:flutter/material.dart';
import 'responsive_card.dart';
import 'responsive_grid.dart';

class DashboardStats extends StatelessWidget {
  final List<DashboardStatItem> items;

  const DashboardStats({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      minChildWidth: 200,
      spacing: 16,
      runSpacing: 16,
      children: items
          .map(
            (item) => ResponsiveCard(
              color: item.color,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item.icon, size: 24),
                      SizedBox(width: 8),
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    item.value,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (item.subtitle != null) ...[
                    SizedBox(height: 8),
                    Text(
                      item.subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class DashboardStatItem {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? color;

  DashboardStatItem({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.color,
  });
}
