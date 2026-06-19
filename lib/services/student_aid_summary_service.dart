import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:madaurore/data/models/fund_reception_model.dart';
import 'package:madaurore/data/models/justification_model.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StudentAidSummaryService {
  StudentAidSummaryService._();

  static final StudentAidSummaryService instance =
      StudentAidSummaryService._();

  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

  Future<Uint8List> buildStudentDossierPdf({
    required UserModel student,
    required RequestModel request,
    required List<FundReceptionModel> receptions,
    required List<JustificationModel> justifications,
    UserModel? coordinator,
  }) async {
    final pdf = pw.Document();
    final grantedAmount = request.montantAccorde ?? request.montant ?? 0;
    final approvedReceived = receptions
        .where((item) => item.isApproved)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final pendingReceived = receptions
        .where((item) => item.isPending || item.needsCorrection)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final approvedJustified = justifications
        .where((item) => item.isApproved)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final pendingJustified = justifications
        .where((item) => item.isPending || item.needsCorrection)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final remainingToReceive = (grantedAmount - approvedReceived).clamp(
      0,
      double.infinity,
    ).toDouble();
    final remainingToJustify = (approvedReceived - approvedJustified).clamp(
      0,
      double.infinity,
    ).toDouble();

    pw.ImageProvider? profileImage;
    if (student.photoUrl != null && student.photoUrl!.trim().isNotEmpty) {
      try {
        profileImage = await networkImage(student.photoUrl!);
      } catch (_) {
        profileImage = null;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _buildHeader(
            student: student,
            request: request,
            profileImage: profileImage,
          ),
          pw.SizedBox(height: 18),
          _buildSectionTitle('Profil et demande'),
          pw.SizedBox(height: 8),
          _buildInfoGrid([
            _infoItem('Email', student.email),
            _infoItem('Region', student.region),
            _infoItem('Statut membre', student.memberStatus ?? 'Non classe'),
            _infoItem(
              'Coordinateur',
              coordinator?.fullName ?? 'Non renseigne',
            ),
            _infoItem('Titre de la demande', request.titre),
            _infoItem('Motif', request.reason ?? 'Non renseigne'),
            _infoItem('Localisation', request.localisation ?? 'Non renseignee'),
            _infoItem(
              'Montant demande',
              _formatCurrency(request.montant ?? 0),
            ),
            _infoItem('Montant accorde', _formatCurrency(grantedAmount)),
            _infoItem(
              'Date de soumission',
              _formatDate(request.createdAt),
            ),
            _infoItem(
              'Validation admin',
              _formatDate(request.adminValidatedAt),
            ),
            _infoItem(
              'Validation conseil',
              _formatDate(request.conseilValidatedAt),
            ),
          ]),
          if (request.studentBio != null && request.studentBio!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _buildParagraphCard('Bio etudiante', request.studentBio!),
          ],
          if (request.coordoNotes != null &&
              request.coordoNotes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _buildParagraphCard('Notes du coordinateur', request.coordoNotes!),
          ],
          pw.SizedBox(height: 18),
          _buildSectionTitle('Synthese financiere'),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMetricCard('Accorde', _formatCurrency(grantedAmount)),
              _buildMetricCard('Recu valide', _formatCurrency(approvedReceived)),
              _buildMetricCard(
                'Depenses validees',
                _formatCurrency(approvedJustified),
              ),
              _buildMetricCard(
                'Reste a recevoir',
                _formatCurrency(remainingToReceive),
              ),
              _buildMetricCard(
                'Reste a justifier',
                _formatCurrency(remainingToJustify),
              ),
              _buildMetricCard(
                'Recu en attente',
                _formatCurrency(pendingReceived),
              ),
              _buildMetricCard(
                'Depenses en attente',
                _formatCurrency(pendingJustified),
              ),
              _buildMetricCard('Statut dossier', request.statusLabel),
            ],
          ),
          pw.SizedBox(height: 18),
          _buildSectionTitle('Historique des receptions'),
          pw.SizedBox(height: 8),
          if (receptions.isEmpty)
            _buildEmptyState('Aucun justificatif de reception enregistre')
          else
            _buildReceptionsTable(receptions),
          pw.SizedBox(height: 18),
          _buildSectionTitle('Historique des depenses'),
          pw.SizedBox(height: 8),
          if (justifications.isEmpty)
            _buildEmptyState('Aucun justificatif de depense enregistre')
          else
            _buildJustificationsTable(justifications),
          pw.SizedBox(height: 18),
          _buildSectionTitle('Annexes et fichiers'),
          pw.SizedBox(height: 8),
          _buildFilesSection(
            title: 'Justificatifs de reception',
            items: receptions
                .map(
                  (item) => _fileLine(
                    item.fileName,
                    item.fileUrl,
                    '${_formatCurrency(item.amount)} - ${FundReceptionModel.statusLabel(item.status)}',
                  ),
                )
                .toList(),
          ),
          pw.SizedBox(height: 10),
          _buildFilesSection(
            title: 'Justificatifs de depense',
            items: justifications
                .map(
                  (item) => _fileLine(
                    item.fileName,
                    item.fileUrl,
                    '${_formatCurrency(item.amount)} - ${JustificationModel.statusLabel(item.status)}',
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader({
    required UserModel student,
    required RequestModel request,
    required pw.ImageProvider? profileImage,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(12),
        color: PdfColors.grey100,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 84,
            height: 84,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: PdfColors.grey300,
            ),
            child: profileImage != null
                ? pw.ClipOval(child: pw.Image(profileImage, fit: pw.BoxFit.cover))
                : pw.Center(
                    child: pw.Text(
                      _initialFor(student.fullName),
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Fiche dossier etudiant',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  student.fullName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Reference dossier : ${request.id}'),
                pw.Text('Date d\'export : ${_formatDate(DateTime.now())}'),
                pw.Text('Statut : ${request.statusLabel}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
    );
  }

  pw.Widget _buildInfoGrid(List<MapEntry<String, String>> items) {
    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => pw.Container(
              width: 250,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item.key,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    item.value,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _buildParagraphCard(String title, String content) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(content),
        ],
      ),
    );
  }

  pw.Widget _buildMetricCard(String label, String value) {
    return pw.Container(
      width: 122,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildReceptionsTable(List<FundReceptionModel> receptions) {
    return pw.TableHelper.fromTextArray(
      headers: ['Date', 'Montant', 'Statut', 'Fichier'],
      data: receptions
          .map(
            (item) => [
              _formatDate(item.receivedDate),
              _formatCurrency(item.amount),
              FundReceptionModel.statusLabel(item.status),
              item.fileName,
            ],
          )
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignment: pw.Alignment.centerLeft,
      cellHeight: 26,
    );
  }

  pw.Widget _buildJustificationsTable(List<JustificationModel> justifications) {
    return pw.TableHelper.fromTextArray(
      headers: ['Date', 'Categorie', 'Montant', 'Statut', 'Fichier'],
      data: justifications
          .map(
            (item) => [
              _formatDate(item.expenseDate),
              JustificationModel.categoryLabel(item.category),
              _formatCurrency(item.amount),
              JustificationModel.statusLabel(item.status),
              item.fileName,
            ],
          )
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignment: pw.Alignment.centerLeft,
      cellHeight: 26,
    );
  }

  pw.Widget _buildFilesSection({
    required String title,
    required List<pw.Widget> items,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (items.isEmpty)
            pw.Text('Aucun fichier associe')
          else
            ...items,
        ],
      ),
    );
  }

  pw.Widget _fileLine(String name, String url, String details) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.UrlLink(
            destination: url,
            child: pw.Text(
              name,
              style: const pw.TextStyle(
                color: PdfColors.blue700,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
          pw.Text(details, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(url, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  pw.Widget _buildEmptyState(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.grey100,
      ),
      child: pw.Text(message),
    );
  }

  MapEntry<String, String> _infoItem(String label, String value) {
    return MapEntry(label, value);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Non renseignee';
    return _dateFormatter.format(date);
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.decimalPattern('fr_FR');
    return '${formatter.format(amount.round())} Ar';
  }

  String _initialFor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}
