import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';

import 'core/constants/app_theme.dart';
import 'data/repositories/app_auth_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard/admin/dashboard_admin_screen.dart';
import 'presentation/screens/dashboard/coordinator/dashboard_coordo_screen.dart';
import 'presentation/screens/dashboard/student/dashboard_student_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('✅ Firebase initialisé avec succès');

    runApp(const MadactionApp());
  } catch (e) {
    debugPrint('❌ Erreur d\'initialisation: $e');
    runApp(const ErrorApp());
  }
}

// Application principale
class MadactionApp extends StatelessWidget {
  const MadactionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(const Duration(milliseconds: 800)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school, size: 100, color: Colors.blue),
                    SizedBox(height: 20),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          );
        }
        return ChangeNotifierProvider<AppAuthProvider>(
          create: (_) => AppAuthProvider(),
          child: MaterialApp(
            title: 'Madaction',
            theme: appTheme,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('fr', ''), Locale('en', '')],
            initialRoute: '/login',
            routes: {
              '/login': (context) => const LoginScreen(),
              '/admin/dashboard_admin': (context) =>
                  const DashboardAdminScreen(),
              '/coordinator/dashboard_coordo': (context) =>
                  const DashboardCoordoScreen(),
              '/student/dashboard_student': (context) =>
                  const DashboardStudentScreen(),
            },
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              );
            },
          ),
        );
      },
    );
  }
}

// Widget d'erreur
class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'Erreur d\'initialisation',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Impossible de démarrer l\'application.\nVérifiez votre configuration Firebase.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => runApp(const MadactionApp()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
