import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:madaurore/core/utils/member_status_utils.dart';
import 'package:madaurore/core/utils/region_utils.dart';

class RequestModel {
  final String id;
  final String titre;
  final String
  statut; // 'pending', 'approved_admin', 'approved_council', 'rejected'
  final String region;
  final DateTime createdAt;
  final String userId;
  final String? localisation;
  final String? pdfUrl;
  final String? justificationUrl;
  final String? reason;

  // 🔑 CHAMPS FINANCIERS
  final double? montant;
  final double? montantAccorde;

  // 📝 BIO ÉTUDIANT
  final String? studentBio;

  // 🔄 TIMESTAMPS DE VALIDATION
  final DateTime? adminValidatedAt;
  final String? adminValidatedBy;
  final DateTime? conseilValidatedAt;
  final String? conseilValidatedBy;

  // ➕ NOUVEAU - NOTES DU COORDO
  final String? memberStatus; // 'nouveau_membre', 'ancien_membre'
  final String? coordoNotes; // Notes du coordo régional
  final DateTime? coordoNotesAt;
  final String? coordoNotesBy;

  RequestModel({
    required this.id,
    required this.titre,
    required this.statut,
    required this.region,
    required this.createdAt,
    required this.userId,
    this.localisation,
    this.pdfUrl,
    this.justificationUrl,
    this.reason,
    this.montant,
    this.montantAccorde,
    this.studentBio,
    this.adminValidatedAt,
    this.adminValidatedBy,
    this.conseilValidatedAt,
    this.conseilValidatedBy,
    this.memberStatus,
    this.coordoNotes,
    this.coordoNotesAt,
    this.coordoNotesBy,
  });

  factory RequestModel.fromDocument(DocumentSnapshot doc) {
    if (!doc.exists) {
      throw Exception('Document demande introuvable');
    }
    final data = doc.data() as Map<String, dynamic>;
    return RequestModel.fromMap(data, doc.id);
  }

  factory RequestModel.fromMap(Map<String, dynamic> map, String id) {
    return RequestModel(
      id: id,
      titre: map['titre'] as String? ?? 'Sans titre',
      statut: map['statut'] as String? ?? 'pending',
      region: RegionUtils.normalize(map['region'] as String?),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      userId: map['userId'] as String? ?? '',
      localisation: map['localisation'] as String?,
      pdfUrl: map['pdfUrl'] as String?,
      justificationUrl: map['justificationUrl'] as String?,
      reason: map['reason'] as String?,
      montant: _parseDouble(map['montant']),
      montantAccorde: _parseDouble(map['montantAccorde']),
      studentBio: map['studentBio'] as String?,
      adminValidatedAt: _parseDate(map['adminValidatedAt']),
      adminValidatedBy: map['adminValidatedBy'] as String?,
      conseilValidatedAt: _parseDate(map['conseilValidatedAt']),
      conseilValidatedBy: map['conseilValidatedBy'] as String?,
      memberStatus: MemberStatusUtils.normalize(map['memberStatus'] as String?),
      coordoNotes: map['coordoNotes'] as String?,
      coordoNotesAt: _parseDate(map['coordoNotesAt']),
      coordoNotesBy: map['coordoNotesBy'] as String?,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      if (value.trim().isEmpty) return null;
      return double.tryParse(value);
    }
    return null;
  }

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is Timestamp) return date.toDate();
    if (date is DateTime) return date;
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (e) {
        return null;
      }
    }
    if (date is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(date);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'titre': titre,
      'statut': statut,
      'region': RegionUtils.normalize(region),
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'localisation': localisation,
      'pdfUrl': pdfUrl,
      'justificationUrl': justificationUrl,
      'reason': reason,
      'montant': montant,
      'montantAccorde': montantAccorde,
      'studentBio': studentBio,
      'adminValidatedAt': adminValidatedAt != null
          ? Timestamp.fromDate(adminValidatedAt!)
          : null,
      'adminValidatedBy': adminValidatedBy,
      'conseilValidatedAt': conseilValidatedAt != null
          ? Timestamp.fromDate(conseilValidatedAt!)
          : null,
      'conseilValidatedBy': conseilValidatedBy,
      'memberStatus': MemberStatusUtils.normalize(memberStatus),
      'coordoNotes': coordoNotes,
      'coordoNotesAt': coordoNotesAt != null
          ? Timestamp.fromDate(coordoNotesAt!)
          : null,
      'coordoNotesBy': coordoNotesBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  RequestModel copyWith({
    String? titre,
    String? statut,
    DateTime? adminValidatedAt,
    String? adminValidatedBy,
    DateTime? conseilValidatedAt,
    String? conseilValidatedBy,
    double? montantAccorde,
    String? studentBio,
    String? memberStatus,
    String? coordoNotes,
    DateTime? coordoNotesAt,
    String? coordoNotesBy,
  }) {
    return RequestModel(
      id: id,
      titre: titre ?? this.titre,
      statut: statut ?? this.statut,
      region: region,
      createdAt: createdAt,
      userId: userId,
      localisation: localisation,
      pdfUrl: pdfUrl,
      justificationUrl: justificationUrl,
      reason: reason,
      montant: montant,
      montantAccorde: montantAccorde ?? this.montantAccorde,
      studentBio: studentBio ?? this.studentBio,
      adminValidatedAt: adminValidatedAt ?? this.adminValidatedAt,
      adminValidatedBy: adminValidatedBy ?? this.adminValidatedBy,
      conseilValidatedAt: conseilValidatedAt ?? this.conseilValidatedAt,
      conseilValidatedBy: conseilValidatedBy ?? this.conseilValidatedBy,
      memberStatus: memberStatus ?? this.memberStatus,
      coordoNotes: coordoNotes ?? this.coordoNotes,
      coordoNotesAt: coordoNotesAt ?? this.coordoNotesAt,
      coordoNotesBy: coordoNotesBy ?? this.coordoNotesBy,
    );
  }

  bool get isPending => statut == 'pending';
  bool get isApprovedAdmin => statut == 'approved_admin';
  bool get isApprovedCouncil => statut == 'approved_council';
  bool get isRejected => statut == 'rejected';
  bool get hasBio => studentBio != null && studentBio!.isNotEmpty;

  bool get isEnAttente => isPending;
  bool get isApprouveAdmin => isApprovedAdmin;
  bool get isApprouveConseil => isApprovedCouncil;
  bool get isRejete => isRejected;

  // ✅ NOUVEAU - Supporte multiple formats pour memberStatus
  bool get isNouveauMembre =>
      MemberStatusUtils.normalize(memberStatus) == MemberStatusUtils.newMember;
  bool get isAncienMembre =>
      MemberStatusUtils.normalize(memberStatus) == MemberStatusUtils.oldMember;
  bool get isNonClasseMembre => MemberStatusUtils.isUnclassified(memberStatus);
  String get memberStatusLabel => MemberStatusUtils.label(memberStatus);
  String get memberStatusShortLabel =>
      MemberStatusUtils.shortLabel(memberStatus);
  bool get hasCoordonotes => coordoNotes != null && coordoNotes!.isNotEmpty;

  String get statusLabel {
    if (isPending) return 'En attente';
    if (isApprovedAdmin) return 'Approuvée (Admin)';
    if (isApprovedCouncil) return 'Approuvée (Conseil)';
    if (isRejected) return 'Rejetée';
    return statut;
  }

  String get normalizedStatut => statusLabel;

  @override
  String toString() {
    return 'RequestModel(id: $id, titre: $titre, statut: $statut, region: $region)';
  }
}
