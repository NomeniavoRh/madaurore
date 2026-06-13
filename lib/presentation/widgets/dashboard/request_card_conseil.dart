import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/presentation/screens/dashboard/student/justification_upload_screen.dart';
import 'package:madaurore/presentation/widgets/dashboard/montant_dialog.dart';

/// Card d'une requête pour le Conseil Administratif
class RequestCardConseil extends StatelessWidget {
  final RequestModel request;
  final FirebaseFirestore firestore;

  const RequestCardConseil({
    super.key,
    required this.request,
    required this.firestore,
  });

  Future<void> _openPdf(BuildContext context, String? url) async {
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le PDF')),
        );
      }
    }
  }

  Future<void> _updateRequestTranche(
    BuildContext context,
    double montant,
  ) async {
    if (montant <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Montant invalide')));
      }
      return;
    }

    try {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);

      await firestore.collection('requests').doc(request.id).update({
        'statut': 'approved_council',
        'montantAccorde': montant,
        'conseilValidatedAt': FieldValue.serverTimestamp(),
        'conseilValidatedBy': auth.userModel!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Montant de $montant Ar confirmé'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    onPressed: () => _openPdf(context, request.pdfUrl),
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
                    label: const Text('Justificatifs de depenses'),
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
                    onPressed: () => showMontantDialog(
                      context,
                      request,
                      (montant) => _updateRequestTranche(context, montant),
                    ),
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
}
