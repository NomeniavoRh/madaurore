import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/data/repositories/request_repository.dart';
import 'package:madaurore/data/repositories/user_repository.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/presentation/screens/auth/login_screen.dart';
import 'package:madaurore/presentation/screens/dashboard/student/justification_upload_screen.dart';
import 'package:madaurore/presentation/screens/students/admin/student_list_admin_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DashboardAdminScreen extends StatefulWidget {
  static const routeName = '/admin/dashboard_admin';

  const DashboardAdminScreen({super.key});

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  final RequestRepository _requestRepository = RequestRepository();
  final UserRepository _userRepository = UserRepository();

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
            'statut': 'approved_admin',
            'adminValidatedAt': FieldValue.serverTimestamp(),
            'adminValidatedBy': Provider.of<AppAuthProvider>(
              context,
              listen: false,
            ).userModel!.uid,
            'updatedAt': FieldValue.serverTimestamp(),
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
            'statut': 'rejected',
            'reason': reasonController.text.trim(),
            'adminValidatedAt': FieldValue.serverTimestamp(),
            'adminValidatedBy': Provider.of<AppAuthProvider>(
              context,
              listen: false,
            ).userModel!.uid,
            'updatedAt': FieldValue.serverTimestamp(),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Statut: ${request.normalizedStatut}',
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
                          const SizedBox(height: 8),
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
                        if (request.isApprouveConseil ||
                            request.justificationUrl != null) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                this.context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      JustificationUploadScreen(
                                        requestId: request.id,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.receipt_long),
                            label: const Text('Justificatifs de depenses'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (request.isEnAttente) ...[
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
                        if (request.isApprouveAdmin)
                          Text(
                            '✅ Approuvé par l\'admin',
                            style: GoogleFonts.poppins(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (request.isRejete)
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
    return _requestRepository.watchRequests(limit: 500);
  }

  Future<void> _approvePendingUser(UserModel user) async {
    try {
      await _userRepository.approveUser(user.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Compte approuvé : ${user.fullName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur approbation: $e')));
    }
  }

  Future<void> _rejectPendingUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter le compte'),
        content: Text(
          'Voulez-vous vraiment rejeter le compte de ${user.fullName} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _userRepository.rejectUser(user.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Compte rejeté : ${user.fullName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur rejet: $e')));
    }
  }

  String _getUserRoleLabel(String role) {
    switch (UserModel.normalizeRole(role)) {
      case 'admin':
        return 'Administrateur';
      case 'regional_coordinator':
        return 'Coordinateur régional';
      case 'Conseil_Administratif':
        return 'Conseil Admin';
      case 'student':
        return 'Étudiant';
      default:
        return role;
    }
  }

  Widget _buildPendingUsersSection() {
    return StreamBuilder<List<UserModel>>(
      stream: _userRepository.getPendingUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Erreur comptes en attente: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final pendingUsers = snapshot.data ?? [];

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.manage_accounts, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Comptes en attente',
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text('${pendingUsers.length}'),
                      backgroundColor: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (pendingUsers.isEmpty)
                  Text(
                    'Aucun compte à approuver pour le moment.',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  )
                else
                  ...pendingUsers.map(_buildPendingUserTile),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingUserTile(UserModel user) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_getUserRoleLabel(user.role)} - ${user.region}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _approvePendingUser(user),
                icon: const Icon(Icons.check_circle),
                label: const Text('Approuver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _rejectPendingUser(user),
                icon: const Icon(Icons.block),
                label: const Text('Rejeter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, double> _calculateTotalByRegion(List<RequestModel> requests) {
    final Map<String, double> totals = {};
    for (final request in requests) {
      final montant = request.montant ?? 0.0;

      totals.update(
        request.region,
        (value) => value + montant,
        ifAbsent: () => montant,
      );
    }
    return totals;
  }

  Map<String, int> _calculateRequestCounts(List<RequestModel> requests) {
    final Map<String, int> counts = {};
    for (final request in requests) {
      counts.update(request.region, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  String _formatCurrency(double amount) {
    if (amount == 0) return '0 Ar';
    final s = amount.toInt().toString();
    if (s.length <= 3) return '$s Ar';
    return '${s.substring(0, s.length - 3)} ${s.substring(s.length - 3)} Ar';
  }

  Future<void> _exportGlobalReport(List<RequestModel> requests) async {
    if (requests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune demande à exporter')),
      );
      return;
    }

    final pdf = pw.Document();

    // Calculer les totaux
    final totals = _calculateTotalByRegion(requests);
    final totalGlobal = totals.values.fold(0.0, (a, b) => a + b);
    final counts = _calculateRequestCounts(requests);

    // Ajouter la page de titre
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'RAPPORT GLOBAL DES DEMANDES',
              style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Généré le ${DateTime.now().toString().split('.')[0]}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 40),
            pw.Text(
              'STATISTIQUES GLOBALES',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                pw.Column(
                  children: [
                    pw.Text(
                      'Total Demandes',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      '${requests.length}',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(
                      'Total Engagé',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      _formatCurrency(totalGlobal),
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('Régions', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(
                      '${totals.length}',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Ajouter la page des statistiques par région
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Text(
            'MONTANTS PAR RÉGION',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            headers: ['Région', 'Nombre', 'Montant Total'],
            data: totals.entries
                .map(
                  (e) => [
                    e.key,
                    (counts[e.key] ?? 0).toString(),
                    _formatCurrency(e.value),
                  ],
                )
                .toList(),
            border: null,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellHeight: 30,
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'TOTAL GLOBAL: ',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.Text(
                _formatCurrency(totalGlobal),
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Ajouter la page détaillée
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Text(
            'DÉTAIL DES DEMANDES',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            headers: ['Titre', 'Région', 'Raison', 'Montant', 'Statut'],
            data: requests
                .take(50)
                .map(
                  (r) => [
                    r.titre.length > 20
                        ? '${r.titre.substring(0, 20)}...'
                        : r.titre,
                    r.region,
                    r.reason ?? 'N/A',
                    _formatCurrency(r.montant ?? 0),
                    r.statut,
                  ],
                )
                .toList(),
            border: null,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellHeight: 25,
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    // Exporter le PDF
    final Uint8List bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Rapport généré et ouvert pour impression/partage'),
        ),
      );
    }
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
            icon: const Icon(Icons.people),
            tooltip: 'Membres inscrits',
            onPressed: () {
              Navigator.pushNamed(context, '/admin/member-list');
            },
          ),
          IconButton(
            icon: const Icon(Icons.school),
            tooltip: 'Étudiants parrainés',
            onPressed: () {
              Navigator.pushNamed(context, StudentListAdminScreen.routeName);
            },
          ),
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
              // ========== PROFILE CARD ==========
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      color: Colors.black.withValues(alpha: 0.1),
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
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: AppColors.accent,
                                  backgroundImage: profile.photoUrl != null
                                      ? NetworkImage(profile.photoUrl!)
                                      : null,
                                  child: profile.photoUrl == null
                                      ? const Icon(
                                          Icons.admin_panel_settings,
                                          size: 50,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/profile/edit',
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
                                'Administrateur',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: AppColors.accent.withValues(
                                alpha: 0.5,
                              ),
                              labelStyle: TextStyle(color: AppColors.primary),
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
              _buildPendingUsersSection(),
              const SizedBox(height: 24),
              Text(
                'Gestion des Demandes',
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'Erreur: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        final requests = snapshot.data ?? [];

        // Debug: afficher dans la console
        debugPrint('📊 Total requests: ${requests.length}');
        if (requests.isNotEmpty) {
          final regions = requests.map((r) => r.region).toSet().toList();
          debugPrint('📍 Régions trouvées: ${regions.join(", ")}');
        }

        final totals = _calculateTotalByRegion(requests);
        final counts = _calculateRequestCounts(requests);
        final totalGlobal = totals.values.fold(0.0, (a, b) => a + b);

        // Si aucune demande
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Aucune demande trouvée',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les demandes des étudiants apparaîtront ici',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // ========== STATISTIQUES GLOBALES ==========
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 RÉSUMÉ FINANCIER GLOBAL',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Engagé: ${_formatCurrency(totalGlobal)}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nombre de demandes: ${requests.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nombre de régions: ${totals.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ========== MONTANTS PAR RÉGION ==========
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💰 MONTANTS PAR RÉGION',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...totals.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.accent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    '${counts[entry.key] ?? 0} demandes',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _formatCurrency(entry.value),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ========== BOUTON EXPORT ==========
            ElevatedButton.icon(
              onPressed: () => _exportGlobalReport(requests),
              icon: const Icon(Icons.file_download),
              label: const Text('📥 Télécharger Rapport Global (PDF)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // ========== LISTE DES DEMANDES ==========
            Text(
              'Demandes de Toutes les Régions (${requests.length})',
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          _formatCurrency(request.montant ?? 0).substring(0, 2),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      request.titre,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${request.region} • ${_formatCurrency(request.montant ?? 0)} • ${request.normalizedStatut}',
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          request.statut,
                        ).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusLabel(request.statut),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(request.statut),
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

  Color _getStatusColor(String statut) {
    if (statut == 'pending') {
      return AppColors.pending;
    }
    if (statut == 'approved_admin' || statut == 'approved_council') {
      return AppColors.success;
    }
    if (statut == 'rejected') {
      return AppColors.error;
    }
    return Colors.grey;
  }

  String _getStatusLabel(String statut) {
    if (statut == 'pending') {
      return 'En attente';
    }
    if (statut == 'approved_admin') {
      return 'Approuvée (Admin)';
    }
    if (statut == 'approved_council') {
      return 'Approuvée (Conseil)';
    }
    if (statut == 'rejected') {
      return 'Rejetée';
    }
    return statut;
  }
}
