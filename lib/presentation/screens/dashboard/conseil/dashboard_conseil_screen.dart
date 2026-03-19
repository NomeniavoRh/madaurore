import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madaurore/presentation/screens/auth/login_screen.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardConseilScreen extends StatefulWidget {
  static const routeName = '/conseil/dashboard_conseil';
  const DashboardConseilScreen({super.key});

  @override
  State<DashboardConseilScreen> createState() => _DashboardConseilScreenState();
}

class _DashboardConseilScreenState extends State<DashboardConseilScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
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
      if (doc.exists) {
        return UserModel.fromDocument(doc);
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  Future<void> _approveAmount(
    RequestModel request,
    double montantAccorde,
    BuildContext context,
  ) async {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(request.id)
          .update({
            'statut': 'approuve_conseil',
            'montantAccorde': montantAccorde,
            'conseilValidatedAt': FieldValue.serverTimestamp(),
            'conseilValidatedBy': auth.userModel!.uid,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Montant de ${_formatCurrency(montantAccorde)} approuvé',
            ),
          ),
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


  Future<void> _showMontantDialog(
    RequestModel request,
    BuildContext context,
  ) async {
    final controller = TextEditingController();
    controller.text = request.montant?.toString() ?? '0';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approuver le montant pour ${request.titre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Montant demandé : ${_formatCurrency(request.montant)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant à accorder (Ar)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final montant = double.tryParse(controller.text) ?? 0;
              if (montant > 0) {
                Navigator.pop(context);
                _approveAmount(request, montant, context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Montant invalide')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('✅ Confirmer'),
          ),
        ],
      ),
    );
  }

  void _viewRequestDetails(RequestModel request, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<UserModel?>(
        future: _fetchUserFromId(request.userId),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statut: ${request.statut}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Région: ${request.region}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting)
                          const Text('Chargement utilisateur...'),
                        if (userSnapshot.hasData &&
                            userSnapshot.data != null) ...[
                          Text(
                            'Utilisateur: ${userSnapshot.data!.fullName}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Email: ${userSnapshot.data!.email}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (request.reason != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Raison: ${request.reason}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.error,
                            ),
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
                            label: const Text('Voir justificatif'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        if (request.justificationUrl != null) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openPdf(request.justificationUrl),
                            icon: const Icon(Icons.attachment),
                            label: const Text('Voir pièce justificative'),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (request.statut == 'approuve_admin') ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '💰 Montant demandé : ${_formatCurrency(request.montant)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '⚠️ Vous pouvez modifier ce montant avant approbation',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () =>
                                _showMontantDialog(request, context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              '✅ Approuver le montant',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                        if (request.statut == 'approuve_conseil') ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '✅ Montant accordé : ${_formatCurrency(request.montantAccorde ?? 0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Cette demande est finalisée et archivée.',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (request.statut == 'rejeté')
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '❌ Rejeté',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                    fontSize: 16,
                                  ),
                                ),
                                if (request.reason != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Raison: ${request.reason}',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
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

  Stream<List<RequestModel>> _streamConseilRequests() {
    return FirebaseFirestore.instance
        .collection('requests')
        .where('statut', isEqualTo: 'approuve_admin')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RequestModel.fromDocument(doc))
              .toList(),
        );
  }

  Map<String, double> _calculateTotals(List<RequestModel> requests) {
    final Map<String, double> totals = {};
    for (final request in requests) {
      final region = request.region;
      final montantReel = request.montantAccorde ?? request.montant ?? 0.0;
      totals[region] = (totals[region] ?? 0) + montantReel;
    }
    return totals;
  }

  String _formatCurrency(double? amount) {
    if (amount == null || amount == 0) return '0 Ar';
    final s = amount.toInt().toString();
    if (s.length <= 3) return '$s Ar';
    return '${s.substring(0, s.length - 3)} ${s.substring(s.length - 3)} Ar';
  }

  Widget _buildUserProfileCard(UserModel userModel) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.account_balance,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userModel.fullName,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Conseil Administratif — ${userModel.region}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '📍 Vous validez les montants pour TOUTES les régions',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return StreamBuilder<List<RequestModel>>(
      stream: _streamConseilRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          if (error.contains('failed-precondition')) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '❌ Erreur Firestore : Index manquant',
                    style: GoogleFonts.poppins(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Créez l\'index composite (statut, createdAt) dans la console Firebase.',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        final requests = snapshot.data ?? [];
        final totals = _calculateTotals(requests);
        final totalGlobal = totals.values.fold(0.0, (a, b) => a + b);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(13),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📊 Résumé financier engagé',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Total engagé : ${_formatCurrency(totalGlobal)}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: totals.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${entry.key}: ${_formatCurrency(entry.value)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestsSection() {
    return StreamBuilder<List<RequestModel>>(
      stream: _streamConseilRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        final requests = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📋 Demandes à traiter (${requests.length})',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            if (requests.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '✅ Aucune demande à traiter — tout est à jour !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(26),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.euro,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        request.titre,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Région: ${request.region} • À valider',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Demandé: ${_formatCurrency(request.montant)}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(77),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'À traiter',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AppAuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoadingUserModel) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (auth.user == null || auth.userModel == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, LoginScreen.routeName);
          });
          return const SizedBox();
        }

        if (auth.userModel!.role != 'Conseil_Administratif' &&
            auth.userModel!.role != 'admin') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Accès réservé au Conseil Administratif'),
              ),
            );
            Navigator.pushReplacementNamed(context, LoginScreen.routeName);
          });
          return const SizedBox();
        }

        final userModel = auth.userModel!;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Conseil Administratif — Décision & Suivi',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                await auth.signOut();
                                if (mounted) {
                                  Navigator.pushReplacementNamed(
                                    context,
                                    LoginScreen.routeName,
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.white,
                              ),
                              tooltip: 'Déconnexion',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildUserProfileCard(userModel),
                    const SizedBox(height: 24),
                    _buildStatisticsCard(),
                    const SizedBox(height: 24),
                    _buildRequestsSection(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
