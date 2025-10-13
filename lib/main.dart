import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'core/constants/app_theme.dart';
import 'data/repositories/app_auth_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard/admin/dashboard_admin_screen.dart';
import 'presentation/screens/dashboard/coordinator/dashboard_coordo_screen.dart';
import 'presentation/screens/dashboard/student/dashboard_student_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );
  runApp(const MadactionApp());
}

class MadactionApp extends StatelessWidget {
  const MadactionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppAuthProvider>(
      create: (_) => AppAuthProvider(),
      child: MaterialApp(
        title: 'Madaction',
        theme: appTheme,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/admin/dashboard_admin': (context) => const DashboardAdminScreen(),
          '/coordinator/dashboard_coordo': (context) =>
              const DashboardCoordoScreen(),
          '/student/dashboard_student': (context) =>
              const DashboardStudentScreen(),
        },
      ),
    );
  }
}
