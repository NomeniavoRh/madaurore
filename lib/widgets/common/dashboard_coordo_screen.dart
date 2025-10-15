import 'package:flutter/material.dart';
import '../../../widgets/common/dashboard_layout.dart';
import '../../../widgets/common/dashboard_stats.dart';
import '../../../widgets/common/responsive_list.dart';

class DashboardCoordoScreen extends StatelessWidget {
  const DashboardCoordoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      title: 'Tableau de bord Coordinateur',
      drawer: _buildDrawer(),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardStats(
              items: [
                DashboardStatItem(
                  title: 'Demandes en attente',
                  value: '12',
                  icon: Icons.pending_actions,
                  color: Colors.orange[100],
                ),
                DashboardStatItem(
                  title: 'Demandes traitées',
                  value: '45',
                  icon: Icons.check_circle,
                  color: Colors.green[100],
                ),
                DashboardStatItem(
                  title: 'Total des demandes',
                  value: '57',
                  icon: Icons.article,
                  color: Colors.blue[100],
                ),
              ],
            ),
            SizedBox(height: 24),
            _buildRecentRequests(),
          ],
        ),
      ),
      actions: [
        IconButton(icon: Icon(Icons.notifications), onPressed: () {}),
        IconButton(icon: Icon(Icons.account_circle), onPressed: () {}),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person),
                ),
                SizedBox(height: 8),
                Text(
                  'Coordinateur',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.dashboard),
            title: Text('Tableau de bord'),
            selected: true,
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.list_alt),
            title: Text('Demandes'),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.people),
            title: Text('Étudiants'),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Paramètres'),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRequests() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demandes récentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ResponsiveList(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: List.generate(
                5,
                (index) => ListTile(
                  title: Text('Demande #${index + 1}'),
                  subtitle: Text('Il y a ${index + 1} heures'),
                  trailing: IconButton(
                    icon: Icon(Icons.arrow_forward),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
