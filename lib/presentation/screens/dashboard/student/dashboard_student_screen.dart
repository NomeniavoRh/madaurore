import 'dart:async'; // Fix: Import pour StreamSubscription
import 'dart:io' show File;
import 'dart:typed_data'; // Pour Uint8List PDF

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart'; // Pour génération PDF
import 'package:pdf/widgets.dart' as pw; // Widgets PDF
import 'package:printing/printing.dart'; // Pour sauvegarde/partage PDF
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/presentation/screens/dashboard/student/justification_upload_screen.dart';
import 'package:madaurore/presentation/screens/dashboard/student/request_submit_screen.dart';
import 'package:madaurore/widgets/common/custom_button.dart';
import 'package:madaurore/widgets/common/custom_card.dart';
import 'package:madaurore/widgets/common/status_badge.dart';

class DashboardStudentScreen extends StatefulWidget {
  static const routeName = '/student/dashboard_student';

  const DashboardStudentScreen({super.key});

  @override
  DashboardStudentScreenState createState() => DashboardStudentScreenState();
}

class DashboardStudentScreenState extends State<DashboardStudentScreen> {
  final TextEditingController _updateContentController =
      TextEditingController();
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot>?
  _requestsSubscription; // Gère subscription pour dispose

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      if (auth.userModel?.role != 'student' ||
          auth.userModel?.status != 'approved') {
        Navigator.pushReplacementNamed(context, '/login');
      }
      _loadLastUpdateDate();
    });
  }

  Future<void> _loadLastUpdateDate() async {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final user = auth.user;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('updates')
            .where('userId', isEqualTo: user.uid)
            .orderBy('date', descending: true)
            .limit(1)
            .get();
        if (doc.docs.isNotEmpty) {
          setState(() {});
        } else {
          setState(() {});
        }
      } catch (e) {
        debugPrint('Erreur loadLastUpdateDate: $e');
        setState(() {});
      }
    }
  }

  Future<void> _uploadJustification() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      if (await file.length() > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fichier trop volumineux, maximum 10 Mo'),
            ),
          );
        }
        return;
      }
      setState(() => _isLoading = true);
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      final user = auth.user;
      if (user != null) {
        try {
          final storageRef = FirebaseStorage.instance.ref().child(
            'justifications/${user.uid}/${result.files.single.name}',
          );
          await storageRef.putFile(file);
          final url = await storageRef.getDownloadURL();
          await FirebaseFirestore.instance.collection('justifications').add({
            'userId': user.uid,
            'url': url,
            'uploadedAt': Timestamp.now(),
            'region': auth.userModel?.region,
          });
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Justificatif envoyé')),
            );
          }
        } catch (e) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Erreur upload: $e')));
          }
        }
      }
    }
  }

  // Fonction PDF export (limit pour mémoire)
  Future<void> _exportRequests(List<RequestModel> requests) async {
    if (requests.isEmpty || !mounted) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Récapitulatif des Demandes',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            headers: ['Titre', 'Raison', 'Statut', 'Région', 'Date Création'],
            data: requests
                .take(10)
                .map(
                  (r) => [
                    r.titre,
                    r.reason ?? 'N/A',
                    r.statut,
                    r.region,
                    r.createdAt.toString().split(' ')[0],
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
          pw.Text(
            'Généré le ${DateTime.now().toString().split(' ')[0]}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    final Uint8List bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF exporté et ouvert pour impression/partage'),
        ),
      );
    }
  }

  Future<void> _showMonthlyUpdateDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mise à jour mensuelle'),
        content: TextField(
          controller: _updateContentController,
          decoration: const InputDecoration(labelText: 'Contenu'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // _submitMonthlyUpdate(); // Si réactivé
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Dialog fermé')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Utilisateur non connecté')),
      );
    }

    // FutureBuilder pour userModel (évite Stream leak constant)
    return FutureBuilder<UserModel?>(
      future: auth.refreshUserModel().then(
        (_) => auth.userModel,
      ), // Fix: Retourne Future<UserModel?>
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final userModel = snapshot.data;
        if (userModel == null ||
            userModel.role != 'student' ||
            userModel.status != 'approved') {
          return const Scaffold(body: Center(child: Text('Accès refusé')));
        }

        return StreamBuilder<List<RequestModel>>(
          stream: FirebaseFirestore.instance
              .collection('requests')
              .where('userId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .limit(20) // Limit pour mémoire
              .snapshots()
              .map(
                (snapshot) => snapshot.docs
                    .map((doc) => RequestModel.fromDocument(doc))
                    .toList(),
              )
              .handleError((e) {
                debugPrint('❌ Erreur requestsStream: $e');
                return Stream.value(<RequestModel>[]); // Fallback vide
              }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final requests = snapshot.data ?? [];
            final hasError = snapshot.hasError;

            return Scaffold(
              appBar: AppBar(
                backgroundColor: AppColors.primary,
                title: Text(
                  'Tableau de bord étudiant',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Carte profil
                    CustomCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: userModel.photoUrl != null
                                  ? NetworkImage(userModel.photoUrl!)
                                  : null,
                              child: userModel.photoUrl == null
                                  ? const Icon(Icons.person, size: 50)
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              userModel.fullName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: AppColors.primary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: AppColors.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  userModel.region,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppColors.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Mes demandes de parrainage',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (hasError)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Erreur de chargement. Réessayez.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      )
                    else if (requests.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Aucune demande pour le moment.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final request = requests[index];
                          return GestureDetector(
                            onTap: request.statut == 'accepté'
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            JustificationUploadScreen(
                                              requestId: request.id,
                                            ),
                                      ),
                                    );
                                  }
                                : null,
                            child: CustomCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      request.titre,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(color: AppColors.primary),
                                    ),
                                    const SizedBox(height: 8),
                                    StatusBadge(status: request.statut),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'Exporter en PDF',
                      onPressed: () => _exportRequests(requests),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'Nouvelle demande',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RequestSubmitScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'Mise à jour mensuelle',
                      onPressed: _showMonthlyUpdateDialog,
                    ),
                    const SizedBox(height: 12),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : CustomButton(
                            text: 'Envoyer justificatif',
                            onPressed: _uploadJustification,
                          ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _updateContentController.dispose();
    _requestsSubscription?.cancel(); // Libère mémoire
    super.dispose();
  }
}
