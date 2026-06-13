import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/data/models/justification_model.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/data/repositories/justification_repository.dart';
import 'package:madaurore/data/repositories/request_repository.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class JustificationUploadScreen extends StatefulWidget {
  final String requestId;

  const JustificationUploadScreen({super.key, required this.requestId});

  @override
  State<JustificationUploadScreen> createState() =>
      _JustificationUploadScreenState();
}

class _JustificationUploadScreenState extends State<JustificationUploadScreen> {
  static const List<String> _categories = [
    'school',
    'transport',
    'housing',
    'supplies',
    'health',
    'other',
  ];

  final RequestRepository _requestRepository = RequestRepository();
  final JustificationRepository _justificationRepository =
      JustificationRepository();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final NumberFormat _moneyFormatter = NumberFormat.decimalPattern('fr_FR');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

  PlatformFile? _selectedFile;
  String _category = 'school';
  DateTime _expenseDate = DateTime.now();
  bool _uploading = false;
  String? _reviewingId;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    setState(() => _selectedFile = result.files.single);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _uploadJustification(
    RequestModel request,
    UserModel user,
  ) async {
    final file = _selectedFile;
    if (file == null) {
      _showMessage('Ajoutez un fichier justificatif');
      return;
    }

    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      _showMessage('Montant invalide');
      return;
    }

    setState(() => _uploading = true);
    try {
      await _justificationRepository.addExpenseJustification(
        request: request,
        student: user,
        file: file,
        amount: amount,
        category: _category,
        expenseDate: _expenseDate,
        note: _noteController.text,
      );

      if (!mounted) return;
      setState(() {
        _selectedFile = null;
        _amountController.clear();
        _noteController.clear();
        _expenseDate = DateTime.now();
      });
      _showMessage('Justificatif ajoute');
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _reviewJustification(
    JustificationModel justification,
    UserModel reviewer,
    String status, {
    String? reason,
  }) async {
    setState(() => _reviewingId = justification.id);
    try {
      await _justificationRepository.reviewJustification(
        justificationId: justification.id,
        status: status,
        reviewer: reviewer,
        rejectionReason: reason,
      );
      if (mounted) _showMessage('Validation mise a jour');
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _reviewingId = null);
    }
  }

  Future<void> _showRejectDialog(
    JustificationModel justification,
    UserModel reviewer,
  ) async {
    final controller = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rejeter le justificatif'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Raison',
              hintText: 'Ex: montant illisible, mauvais document...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Rejeter'),
            ),
          ],
        ),
      );

      if (reason == null) return;
      await _reviewJustification(
        justification,
        reviewer,
        'rejected',
        reason: reason,
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openFile(String url) async {
    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showMessage('Impossible d\'ouvrir le fichier');
      }
    } catch (_) {
      if (mounted) _showMessage('Impossible d\'ouvrir le fichier');
    }
  }

  double? _parseAmount(String value) {
    final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String _formatMoney(double value) {
    return '${_moneyFormatter.format(value.round())} Ar';
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    final sizeInMb = bytes / (1024 * 1024);
    if (sizeInMb >= 1) return '${sizeInMb.toStringAsFixed(1)} Mo';
    return '${(bytes / 1024).toStringAsFixed(0)} Ko';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AppAuthProvider>(context).userModel;

    if (currentUser == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<RequestModel?>(
      stream: _requestRepository.getRequestStream(widget.requestId),
      builder: (context, requestSnapshot) {
        if (requestSnapshot.connectionState == ConnectionState.waiting &&
            !requestSnapshot.hasData) {
          return Scaffold(
            appBar: _buildAppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final request = requestSnapshot.data;
        if (request == null) {
          return Scaffold(
            appBar: _buildAppBar(),
            body: const Center(child: Text('Demande introuvable')),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(),
          body: StreamBuilder<List<JustificationModel>>(
            stream: _justificationRepository.watchForRequest(
              requestId: request.id,
              currentUser: currentUser,
              requestRegion: request.region,
            ),
            builder: (context, justificationsSnapshot) {
              final justifications = justificationsSnapshot.data ?? [];
              final canUpload =
                  currentUser.isStudent &&
                  request.userId == currentUser.uid &&
                  request.isApprouveConseil;
              final canReview = _canReview(currentUser);

              return RefreshIndicator(
                onRefresh: () async =>
                    Future<void>.delayed(const Duration(milliseconds: 250)),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummary(request, justifications),
                    const SizedBox(height: 16),
                    if (canUpload) _buildUploadForm(request, currentUser),
                    if (currentUser.isStudent && !canUpload)
                      _buildInfoPanel(
                        'Les justificatifs seront disponibles apres validation du Conseil.',
                      ),
                    const SizedBox(height: 16),
                    _buildListHeader(justificationsSnapshot),
                    const SizedBox(height: 12),
                    if (justifications.isEmpty)
                      _buildEmptyState()
                    else
                      ...justifications.map(
                        (item) => _JustificationTile(
                          justification: item,
                          moneyFormatter: _formatMoney,
                          dateFormatter: _dateFormatter,
                          fileSizeFormatter: _formatFileSize,
                          isReviewing: _reviewingId == item.id,
                          canReview:
                              canReview &&
                              (item.isPending || item.needsCorrection),
                          onOpen: () => _openFile(item.fileUrl),
                          onApprove: () => _reviewJustification(
                            item,
                            currentUser,
                            'approved',
                          ),
                          onReject: () => _showRejectDialog(item, currentUser),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      title: Text(
        'Justificatifs de depenses',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    );
  }

  bool _canReview(UserModel user) {
    return user.isAdmin ||
        user.isConseilAdministratif ||
        user.isRegionalCoordinator;
  }

  Widget _buildSummary(
    RequestModel request,
    List<JustificationModel> justifications,
  ) {
    final grantedAmount = request.montantAccorde ?? request.montant ?? 0;
    final approvedTotal = _sum(
      justifications
          .where((item) => item.isApproved)
          .map((item) => item.amount),
    );
    final pendingTotal = _sum(
      justifications
          .where((item) => item.isPending || item.needsCorrection)
          .map((item) => item.amount),
    );
    final remaining = grantedAmount - approvedTotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.titre,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Region: ${request.region}',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 700 ? 2 : 4;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: columns == 2 ? 1.7 : 1.5,
                children: [
                  _MetricTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Accorde',
                    value: _formatMoney(grantedAmount),
                    color: AppColors.primary,
                  ),
                  _MetricTile(
                    icon: Icons.verified_outlined,
                    label: 'Valide',
                    value: _formatMoney(approvedTotal),
                    color: AppColors.success,
                  ),
                  _MetricTile(
                    icon: Icons.hourglass_empty,
                    label: 'En attente',
                    value: _formatMoney(pendingTotal),
                    color: AppColors.pending,
                  ),
                  _MetricTile(
                    icon: Icons.assignment_late_outlined,
                    label: 'Reste',
                    value: _formatMoney(remaining > 0 ? remaining : 0),
                    color: remaining <= 0 ? AppColors.success : AppColors.error,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUploadForm(RequestModel request, UserModel currentUser) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withAlpha(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ajouter une depense',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Montant justifie',
              suffixText: 'Ar',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Categorie',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(
                            JustificationModel.categoryLabel(category),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_dateFormatter.format(_expenseDate)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withAlpha(160)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'Ex: inscription, transport, achat de fournitures',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    _selectedFile == null
                        ? 'Choisir PDF ou image'
                        : _selectedFile!.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withAlpha(160)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _uploading
                    ? null
                    : () => _uploadJustification(request, currentUser),
                icon: _uploading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_uploading ? 'Envoi...' : 'Ajouter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Formats acceptes: PDF, JPG, PNG. Taille maximum: 10 Mo.',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pending.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.pending.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.pending),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader(AsyncSnapshot<List<JustificationModel>> snapshot) {
    return Row(
      children: [
        Text(
          'Pieces justificatives',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (snapshot.connectionState == ConnectionState.waiting)
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withAlpha(18)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: AppColors.textSecondary,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            'Aucun justificatif ajoute',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  double _sum(Iterable<double> values) {
    return values.fold<double>(0, (total, value) => total + value);
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _JustificationTile extends StatelessWidget {
  final JustificationModel justification;
  final String Function(double value) moneyFormatter;
  final DateFormat dateFormatter;
  final String Function(int bytes) fileSizeFormatter;
  final bool canReview;
  final bool isReviewing;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _JustificationTile({
    required this.justification,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.fileSizeFormatter,
    required this.canReview,
    required this.isReviewing,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(justification.status);
    final fileSize = fileSizeFormatter(justification.fileSize);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.receipt_outlined, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moneyFormatter(justification.amount),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${JustificationModel.categoryLabel(justification.category)} - ${dateFormatter.format(justification.expenseDate)}',
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(
                  label: JustificationModel.statusLabel(justification.status),
                  color: statusColor,
                ),
              ],
            ),
            if (justification.note != null &&
                justification.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                justification.note!,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
            if (justification.rejectionReason != null &&
                justification.rejectionReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(24),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Raison: ${justification.rejectionReason}',
                  style: GoogleFonts.poppins(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      fileSize.isEmpty
                          ? justification.fileName
                          : '${justification.fileName} ($fileSize)',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (justification.reviewedAt != null ||
                justification.reviewerName != null) ...[
              const SizedBox(height: 8),
              Text(
                _reviewLabel(),
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
            if (canReview) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isReviewing ? null : onApprove,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Valider'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isReviewing ? null : onReject,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Rejeter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _reviewLabel() {
    final reviewer = justification.reviewerName ?? 'Equipe';
    final date = justification.reviewedAt == null
        ? ''
        : ' le ${dateFormatter.format(justification.reviewedAt!)}';
    return 'Controle par $reviewer$date';
  }

  Color _statusColor(String status) {
    switch (JustificationModel.normalizeStatus(status)) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'needs_correction':
        return Colors.deepOrange;
      default:
        return AppColors.pending;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
