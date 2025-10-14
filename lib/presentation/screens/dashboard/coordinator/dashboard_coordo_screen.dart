import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/services/firestore_service.dart';
import 'package:madaurore/widgets/common/custom_button.dart';
import 'package:madaurore/widgets/common/custom_card.dart';
import 'package:madaurore/widgets/common/status_badge.dart';

class DashboardCoordoScreen extends StatefulWidget {
  static const routeName = '/coordinator/dashboard_coordo';

  const DashboardCoordoScreen({super.key});

  @override
  DashboardCoordoScreenState createState() => DashboardCoordoScreenState();
}

class DashboardCoordoScreenState extends State<DashboardCoordoScreen> {
  final TextEditingController _updateContentController =
      TextEditingController();
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      if (auth.userModel?.role != 'regional_coordinator' ||
          auth.userModel?.status != 'approved') {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  Future<void> _showRequestDetailsDialog(RequestModel request) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
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
                          fontSize: 18,
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(status: request.statut),
                      const SizedBox(height: 16),
                      Text(
                        'Raison: ${request.reason ?? 'N/A'}',
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Région: ${request.region}',
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Localisation: ${request.localisation ?? 'N/A'}',
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      if (request.pdfUrl != null) ...[
                        const Text(
                          'PDF Justificatif:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final url = Uri.parse(request.pdfUrl!);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Impossible d\'ouvrir le PDF',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Ouvrir PDF'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Actions:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () =>
                                _validateRequest(request.id, 'accepté'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text(
                              'Accepter',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                _validateRequest(request.id, 'rejeté'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text(
                              'Rejeter',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _validateRequest(String requestId, String newStatus) async {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final user = auth.user;
    if (user != null) {
      setState(() => _isLoading = true);
      try {
        await FirestoreService.instance.updateRequest(requestId, newStatus);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Demande $newStatus avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur validation: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

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
    final userModel = auth.userModel;

    if (userModel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Tableau de bord coordinateur',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                        ),
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
                'Demandes de la région ${userModel.region}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<RequestModel>>(
                stream: FirebaseFirestore.instance
                    .collection('requests')
                    .where('region', isEqualTo: userModel.region)
                    .where('statut', isEqualTo: 'en attente')
                    .orderBy('createdAt', descending: true)
                    .limit(20)
                    .snapshots()
                    .map(
                      (snapshot) => snapshot.docs
                          .map((doc) => RequestModel.fromDocument(doc))
                          .toList(),
                    )
                    .handleError((e) {
                      debugPrint('❌ Erreur requestsStream: $e');
                      return Stream.value(<RequestModel>[]);
                    }),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  final requests = snapshot.data ?? [];
                  final hasError = snapshot.hasError;

                  if (hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Erreur de chargement. Réessayez.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    );
                  }

                  if (requests.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Aucune demande en attente.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      ...requests.map(
                        (request) => Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request.titre,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: AppColors.primary),
                                ),
                                const SizedBox(height: 8),
                                StatusBadge(status: request.statut),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => _validateRequest(
                                              request.id,
                                              'accepté',
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                      child: const Text(
                                        'Accepter',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => _validateRequest(
                                              request.id,
                                              'rejeté',
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text(
                                        'Rejeter',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _showRequestDetailsDialog(request),
                                      icon: const Icon(Icons.visibility),
                                      label: const Text('Détails'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      CustomButton(
                        text: 'Exporter en PDF',
                        onPressed: () => _exportRequests(requests),
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Mise à jour mensuelle',
                        onPressed: _showMonthlyUpdateDialog,
                      ),
                      const SizedBox(height: 12),
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else
                        const SizedBox.shrink(),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _updateContentController.dispose();
    _requestsSubscription?.cancel();
    super.dispose();
  }
}
