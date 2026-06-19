import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/data/repositories/request_repository.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/presentation/screens/auth/login_screen.dart';
import 'package:madaurore/presentation/screens/dashboard/student/justification_upload_screen.dart';
import 'package:madaurore/presentation/screens/students/conseil/student_list_conseil_screen.dart';

class DashboardConseilScreen extends StatefulWidget {
  static const routeName = '/conseil/dashboard_conseil';

  const DashboardConseilScreen({super.key});

  @override
  State<DashboardConseilScreen> createState() => _DashboardConseilScreenState();
}

class _DashboardConseilScreenState extends State<DashboardConseilScreen> {
  final RequestRepository _requestRepository = RequestRepository();
  bool _redirectScheduled = false;
  @override
  void initState() {
    super.initState();
  }

  void _checkAuth() {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    if (auth.userModel?.role != 'Conseil_Administratif' &&
        auth.userModel?.role != 'admin') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accès réservé au Conseil Administratif'),
          ),
        );
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
    }
  }

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
        const SnackBar(
          content: Text('AccÃ¨s rÃ©servÃ© au Conseil Administratif'),
        ),
      );
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
    });
  }

  Future<void> _openPdf(String? url) async {
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le PDF')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
            tooltip: 'Étudiants parrainés',
            onPressed: () {
              Navigator.pushNamed(context, StudentListConseilScreen.routeName);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final auth = Provider.of<AppAuthProvider>(context, listen: false);
              await auth.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, LoginScreen.routeName);
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<UserModel?>(
        future: Provider.of<AppAuthProvider>(context, listen: false)
            .refreshUserModel()
            .then((_) {
              return Provider.of<AppAuthProvider>(
                context,
                listen: false,
              ).userModel;
            }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!_canAccessConseilDashboard(snapshot.data)) {
            _redirectToLogin();
            return const Center(child: Text('Profil non trouvé'));
          }

          final userModel = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _buildProfileCard(userModel),
                const SizedBox(height: 20),
                _buildStatsSection(),
                const SizedBox(height: 20),
                _buildRequestsSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(UserModel userModel) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: AppColors.accent,
                    backgroundImage: userModel.photoUrl != null
                        ? NetworkImage(userModel.photoUrl!)
                        : null,
                    child: userModel.photoUrl == null
                        ? Icon(Icons.gavel, size: 45, color: Colors.white)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/profile/edit');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                userModel.fullName,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Conseil Administratif',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(
                  'Décision Montants',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                backgroundColor: AppColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            _buildStatCard(
              'À Trancher',
              waiting.toString(),
              AppColors.pending,
              Icons.assessment,
            ),
            _buildStatCard(
              'Décidés',
              decided.toString(),
              AppColors.success,
              Icons.check_circle,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Demandes à Trancher',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<RequestModel>>(
          stream: _requestRepository.getPendingCouncilApprovalStream(
            limit: 500,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final requests = snapshot.data ?? [];

            if (requests.isEmpty) {
              return Center(
                child: Text(
                  'Aucune demande à trancher',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return _buildRequestCard(request);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRequestCard(RequestModel request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ExpansionTile(
        title: Text(
          request.titre,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          'Demandé: ${request.montant ?? 0} Ar',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.pending,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.pending,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'À Trancher',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Région:', request.region),
                _buildDetailRow('Raison:', request.reason ?? 'N/A'),
                _buildDetailRow(
                  'Montant Demandé:',
                  '${request.montant ?? 0} Ar',
                ),
                if (request.studentBio != null &&
                    request.studentBio!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Profil:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      request.studentBio!,
                      style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (request.pdfUrl != null) ...[
                  ElevatedButton.icon(
                    onPressed: () => _openPdf(request.pdfUrl),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (request.isApprouveConseil ||
                    request.justificationUrl != null) ...[
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            JustificationUploadScreen(requestId: request.id),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Suivi de l\'aide'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showMontantDialog(request),
                    icon: const Icon(Icons.monetization_on),
                    label: const Text('Fixer Montant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMontantDialog(RequestModel request) async {
    final controller = TextEditingController(
      text: (request.montant ?? 0).toString(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Montant pour ${request.titre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Demandé: ${request.montant ?? 0} Ar',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.pending,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant à accorder (Ar)',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final montant = double.tryParse(controller.text) ?? 0;
    if (montant <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Montant invalide')));
      }
      return;
    }

    try {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);

      await FirebaseFirestore.instance
          .collection('requests')
          .doc(request.id)
          .update({
            'statut': 'approved_council',
            'montantAccorde': montant,
            'conseilValidatedAt': FieldValue.serverTimestamp(),
            'conseilValidatedBy': auth.userModel!.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Montant de $montant Ar confirmé'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
