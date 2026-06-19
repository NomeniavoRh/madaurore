import 'package:cloud_firestore/cloud_firestore.dart';

class FundReceptionModel {
  final String id;
  final String requestId;
  final String userId;
  final String region;
  final double amount;
  final DateTime receivedDate;
  final String? note;
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final String contentType;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? reviewedBy;
  final String? reviewerName;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  const FundReceptionModel({
    required this.id,
    required this.requestId,
    required this.userId,
    required this.region,
    required this.amount,
    required this.receivedDate,
    required this.note,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.contentType,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.reviewedBy,
    this.reviewerName,
    this.reviewedAt,
    this.rejectionReason,
  });

  factory FundReceptionModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FundReceptionModel.fromMap(data, doc.id);
  }

  factory FundReceptionModel.fromMap(Map<String, dynamic> map, String id) {
    return FundReceptionModel(
      id: id,
      requestId: map['requestId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      region: map['region'] as String? ?? '',
      amount: _parseDouble(map['amount']),
      receivedDate: _parseDate(map['receivedDate']) ?? DateTime.now(),
      note: map['note'] as String?,
      fileUrl: map['fileUrl'] as String? ?? '',
      fileName: map['fileName'] as String? ?? 'Justificatif de reception',
      fileSize: _parseInt(map['fileSize']),
      contentType: map['contentType'] as String? ?? 'application/pdf',
      status: normalizeStatus(map['status'] as String?),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']),
      reviewedBy: map['reviewedBy'] as String?,
      reviewerName: map['reviewerName'] as String?,
      reviewedAt: _parseDate(map['reviewedAt']),
      rejectionReason: map['rejectionReason'] as String?,
    );
  }

  static String normalizeStatus(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'approved':
      case 'accepted':
      case 'valide':
        return 'approved';
      case 'rejected':
      case 'refused':
      case 'rejete':
        return 'rejected';
      case 'needs_correction':
      case 'correction':
        return 'needs_correction';
      case 'pending':
      case 'en_attente':
      default:
        return 'pending';
    }
  }

  static String statusLabel(String status) {
    switch (normalizeStatus(status)) {
      case 'approved':
        return 'Valide';
      case 'rejected':
        return 'Rejete';
      case 'needs_correction':
        return 'A corriger';
      default:
        return 'En attente';
    }
  }

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';
  bool get needsCorrection => status == 'needs_correction';

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
