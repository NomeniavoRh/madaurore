import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'firebase_options.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/sizes.dart';
import 'data/repositories/app_auth_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard/admin/dashboard_admin_screen.dart';
import 'presentation/screens/dashboard/coordinator/dashboard_coordo_screen.dart'
    as coordinator_screen;
import 'presentation/screens/dashboard/student/dashboard_student_screen.dart';
import 'presentation/screens/dashboard/conseil/dashboard_conseil_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Initialisation Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialisé avec succès');

    // 2. Configuration Firestore pour Flutter Web (éviter bugs Listen/channel)
    if (kIsWeb) {
      // 🔥 CORRECTION : Ajout de cacheSizeBytes pour éviter les problèmes de mémoire
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 1048576, // 1MB - suffisant pour la démo
      );

      debugPrint(
        'Firestore configuré pour Web → persistence activée (cache limité à 1MB)',
      );
    }

    runApp(const MadactionApp());
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation Firebase: $e');
    runApp(const ErrorApp());
  }
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
          '/admin/dashboard_admin': (context) => const DashboardAdminScreen(),
          '/coordinator/dashboard_coordo': (context) =>
              const coordinator_screen.DashboardCoordoScreen(),
          '/student/dashboard_student': (context) =>
              const DashboardStudentScreen(),
          '/conseil/dashboard_conseil': (context) =>
              const DashboardConseilScreen(),
        },
        onUnknownRoute: (settings) {
          return MaterialPageRoute(builder: (context) => const LoginScreen());
        },
        home: FutureBuilder(
          future: Future.delayed(const Duration(milliseconds: 800)),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.school,
                        size: 100,
                        color: AppColors.primary,
                      ),
                      Sizes.gapMD,
                      const CircularProgressIndicator(),
                    ],
                  ),
                ),
              );
            }
            return const LoginScreen(); // Retourne directement le login après délai
          },
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: Sizes.paddingLG,
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
                  onPressed: () {
                    // Relance l'app (fonction main)
                    main();
                  },
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
