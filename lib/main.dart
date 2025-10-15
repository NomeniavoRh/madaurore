import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/sizes.dart';
import 'data/repositories/app_auth_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
// Importation sans alias pour DashboardAdminScreen
import 'presentation/screens/dashboard/admin/dashboard_admin_screen.dart';
import 'presentation/screens/dashboard/coordinator/dashboard_coordo_screen.dart'
    as coordinator_screen;
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

class MadactionApp extends StatelessWidget {
  const MadactionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(const Duration(milliseconds: 800)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.school, size: 100, color: Colors.blue),
                    Sizes.gapMD, // Utilisation des constantes d'espacement
                    const CircularProgressIndicator(),
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
                  const DashboardAdminScreen(), // Sans le préfixe
              '/coordinator/dashboard_coordo': (context) =>
                  const coordinator_screen.DashboardCoordoScreen(),
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

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: Sizes.paddingLG, // Utilisation des constantes d'espacement
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 80),
                Sizes.gapLG,
                const Text(
                  'Erreur d\'initialisation',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Sizes.gapMD,
                const Text(
                  'Impossible de démarrer l\'application.\nVérifiez votre configuration Firebase.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                Sizes.gapXL,
                ElevatedButton.icon(
                  onPressed: () => runApp(const MadactionApp()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(padding: Sizes.paddingMD),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
