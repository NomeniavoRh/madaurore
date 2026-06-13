import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/data/repositories/request_repository.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/presentation/screens/auth/login_screen.dart';
import 'package:madaurore/presentation/screens/students/conseil/student_list_conseil_screen.dart';
import 'package:madaurore/presentation/widgets/dashboard/profile_card.dart';
import 'package:madaurore/presentation/widgets/dashboard/stat_card.dart';
import 'package:madaurore/presentation/widgets/dashboard/conseil_requests_list.dart';

/// Dashboard pour le Conseil Administratif
/// Role : Fixer les montants finaux pour les demandes approuvées par l'admin
class DashboardConseilScreen extends StatefulWidget {
  static const routeName = '/conseil/dashboard_conseil';

  const DashboardConseilScreen({super.key});

  @override
  State<DashboardConseilScreen> createState() => _DashboardConseilScreenState();
}

class _DashboardConseilScreenState extends State<DashboardConseilScreen> {
  bool _redirectScheduled = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RequestRepository _requestRepository = RequestRepository();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  /// Verifier l'authentification et l'acces
  void _checkAuth() {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    if (auth.userModel?.role != 'Conseil_Administratif' &&
        auth.userModel?.role != 'admin') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acces reserve au Conseil Administratif'),
          ),
        );
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
    }
  }

  /// Verifier l'acces au dashboard
  bool _canAccessConseilDashboard(UserModel? userModel) {
    if (userModel == null || userModel.status != 'approved') {
      return false;
    }
    return userModel.role == 'Conseil_Administratif' ||
        userModel.role == 'admin';
  }

  void _redirectToLogin() {
    if (_redirectScheduled || !mounted) return;
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acces reserve au Conseil Administratif')),
      );
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: FutureBuilder<UserModel?>(
        future: _loadUserModel(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!_canAccessConseilDashboard(snapshot.data)) {
            _redirectToLogin();
            return const Center(child: Text('Profil non trouve'));
          }

          final userModel = snapshot.data!;
          return _buildBody(userModel);
        },
      ),
    );
  }

  /// Charger le modele utilisateur
  Future<UserModel?> _loadUserModel() async {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    await auth.refreshUserModel();
    return auth.userModel;
  }

  /// Construire l'AppBar
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      title: Text(
        'Conseil Administratif',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.school),
          tooltip: 'Etudiants parraines',
          onPressed: () {
            Navigator.pushNamed(context, StudentListConseilScreen.routeName);
          },
        ),
        IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout),
      ],
    );
  }

  /// Gerer la deconnexion
  Future<void> _handleLogout() async {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    await auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
    }
  }

  /// Construire le corps du dashboard
  Widget _buildBody(UserModel userModel) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          ProfileCard(
            userModel: userModel,
            role: 'Conseil Administratif',
            roleIcon: Icons.gavel,
            chipLabel: 'Decision Montants',
            onEditProfileTap: () {
              Navigator.pushNamed(context, '/profile/edit');
            },
          ),
          const SizedBox(height: 20),
          _buildStatsSection(),
          const SizedBox(height: 20),
          ConseilRequestsList(firestore: _firestore),
        ],
      ),
    );
  }

  /// Construire la section des statistiques
  Widget _buildStatsSection() {
    return StreamBuilder<List<RequestModel>>(
      stream: _requestRepository.watchRequests(limit: 500),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final allRequests = snapshot.data!;

        final waiting = allRequests.where((r) => r.isApprouveAdmin).length;
        final decided = allRequests.where((r) => r.isApprouveConseil).length;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StatCard(
              label: 'A Trancher',
              value: waiting.toString(),
              color: AppColors.pending,
              icon: Icons.assessment,
            ),
            StatCard(
              label: 'Decides',
              value: decided.toString(),
              color: AppColors.success,
              icon: Icons.check_circle,
            ),
          ],
        );
      },
    );
  }
}
