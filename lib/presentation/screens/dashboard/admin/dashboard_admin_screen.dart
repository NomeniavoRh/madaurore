import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/presentation/screens/auth/login_screen.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardAdminScreen extends StatefulWidget {
  static const routeName = '/admin/dashboard_admin';
  const DashboardAdminScreen({super.key});

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      if (auth.userModel?.role != 'admin') {
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
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

  Future<UserModel?> _fetchUserFromId(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) return UserModel.fromDocument(doc);
    } catch (e) {
      // ignore
    }
    return null;
  }

  Future<void> _approveRequestAsAdmin(
    RequestModel request,
    BuildContext context,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(request.id)
          .update({
            'statut': 'approuve_admin',
            'adminValidatedAt': FieldValue.serverTimestamp(),
            'adminValidatedBy': Provider.of<AppAuthProvider>(
              context,
              listen: false,
            ).userModel!.uid,
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Demande approuvée par l\'admin')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
      }
    }
  }

  Future<void> _rejectRequest(
    RequestModel request,
    BuildContext context,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter la demande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Veuillez indiquer la raison du rejet :'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Raison',
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
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez indiquer une raison')),
                );
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(request.id)
          .update({
            'statut': 'rejeté',
            'reason': reasonController.text.trim(),
            'rejectedAt': FieldValue.serverTimestamp(),
            'rejectedBy': Provider.of<AppAuthProvider>(
              context,
              listen: false,
            ).userModel!.uid,
          });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ Demande rejetée')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
      }
    }
  }

  void _viewRequestDetails(RequestModel request, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<UserModel?>(
        future: _fetchUserFromId(
          request.userId,
        ), // ✅ CORRIGÉ: userId au lieu de studentId
        builder: (context, userSnapshot) {
          return Dialog(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.titre,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Statut: ${request.statut}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Région: ${request.region}',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        if (userSnapshot.hasData &&
                            userSnapshot.data != null) ...[
                          Text(
                            'Utilisateur: ${userSnapshot.data!.fullName}',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                          Text(
                            'Email: ${userSnapshot.data!.email}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        if (request.reason != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Raison: ${request.reason}',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ],
                        if (request.localisation != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Localisation: ${request.localisation}',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (request.pdfUrl != null)
                          ElevatedButton.icon(
                            onPressed: () => _openPdf(request.pdfUrl),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Voir PDF'),
                          ),
                        if (request.justificationUrl != null) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openPdf(request.justificationUrl),
                            icon: const Icon(Icons.attachment),
                            label: const Text('Voir Justificatif'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (request.statut == 'en attente') ...[
                          ElevatedButton(
                            onPressed: () =>
                                _approveRequestAsAdmin(request, context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('✅ Approuver la demande'),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => _rejectRequest(request, context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('❌ Rejeter la demande'),
                          ),
                        ],
                        if (request.statut == 'approuve_admin')
                          Text(
                            '✅ Approuvé par l\'admin',
                            style: GoogleFonts.poppins(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (request.statut == 'rejeté')
                          Text(
                            '❌ Rejeté',
                            style: GoogleFonts.poppins(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Stream<List<RequestModel>> _streamAllRequests() {
    return FirebaseFirestore.instance
        .collection('requests')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RequestModel.fromDocument(doc))
              .toList(),
        );
  }

  Map<String, int> _calculateRequestCounts(List<RequestModel> requests) {
    final Map<String, int> counts = {};
    for (final request in requests) {
      counts.update(request.region, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Tableau de bord Admin',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final auth = Provider.of<AppAuthProvider>(context, listen: false);
              await auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: <Widget>[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(0, 2),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: StreamBuilder<UserModel?>(
                    stream: Provider.of<AppAuthProvider>(
                      context,
                    ).userModelStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (snapshot.hasData) {
                        final profile = snapshot.data!;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircleAvatar(
                              radius: 50,
                              backgroundColor: Color(0xFFF7B420),
                              child: Icon(
                                Icons.admin_panel_settings,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              profile.fullName,
                              style: GoogleFonts.poppins(
                                color: AppColors.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              profile.region,
                              style: GoogleFonts.poppins(
                                color: AppColors.primary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(
                                profile.role == 'admin'
                                    ? 'Administrateur'
                                    : profile.role == 'regional_coordinator'
                                    ? 'Coordinateur régional'
                                    : 'Étudiant',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: profile.role == 'admin'
                                  ? Colors.blue.withAlpha(50)
                                  : profile.role == 'regional_coordinator'
                                  ? Colors.green.withAlpha(50)
                                  : Colors.grey.withAlpha(50),
                              labelStyle: TextStyle(
                                color: profile.role == 'admin'
                                    ? AppColors.primary
                                    : profile.role == 'regional_coordinator'
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        );
                      }
                      return const Text('Profil non trouvé');
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Demandes de Toutes les Régions',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildAllRequestsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllRequestsSection() {
    return StreamBuilder<List<RequestModel>>(
      stream: _streamAllRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        final requests = snapshot.data ?? [];
        final counts = _calculateRequestCounts(requests);
        final totalGlobal = requests.length;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Total des demandes : $totalGlobal',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: counts.entries.map((entry) {
                      return Chip(
                        label: Text(
                          '${entry.key}: ${entry.value}',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        backgroundColor: AppColors.accent.withAlpha(51),
                        labelStyle: TextStyle(color: AppColors.primary),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(request.titre),
                    subtitle: Text(
                      '${request.region} • ${request.statut}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    trailing: Text(
                      request.createdAt.toLocal().toString().split(' ')[0],
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                    onTap: () => _viewRequestDetails(request, context),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
