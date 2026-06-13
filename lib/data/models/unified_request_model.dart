import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:madaurore/core/utils/region_utils.dart';

/// Modele unifie pour toutes les types de requetes
/// Remplace : RequestModel, SponsorshipRequestModel, ValidationRequestModel
///
/// Champs optionnels selon le type :
/// - type='general' : utilise tous les champs
/// - type='sponsorship' : utilise familySituation, userEmail
/// - type='validation' : utilise requestId (logique d'historique)
class UnifiedRequestModel {
  final String id;

  // 📝 IDENTITE
  final String titre;
  final String region;
  final String userId;
  final String? userEmail;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // 🔌 TYPE et CLASSIFICATION
  final RequestType type; // 'general', 'sponsorship', 'validation'
  final String
  statut; // 'pending', 'approved_admin', 'approved_council', 'rejected'
  final String? memberStatus; // 'nouveau_membre', 'ancien_membre'

  // 📋 CONTENU
  final String? description;
  final String? localisation;
  final String? reason;
  final String? studentBio;
  final String? familySituation;

  // 💰 FINANCES
  final double? montant;
  final double? montantAccorde;

  // 📄 FICHIERS
  final String? pdfUrl;
  final String? justificationUrl;

  // ✅ VALIDATIONS
  final ValidationTimestamp? adminValidation;
  final ValidationTimestamp? conseilValidation;
  final ValidationTimestamp? coordoNotes;

  // 🔗 REFERENCES
  final String?
  requestId; // Si c'est une validation, ref a la requete originale

  UnifiedRequestModel({
    required this.id,
    required this.titre,
    required this.region,
    required this.userId,
    required this.createdAt,
    this.userEmail,
    this.updatedAt,
    this.type = RequestType.general,
    this.statut = 'pending',
    this.memberStatus,
    this.description,
    this.localisation,
    this.reason,
    this.studentBio,
    this.familySituation,
    this.montant,
    this.montantAccorde,
    this.pdfUrl,
    this.justificationUrl,
    this.adminValidation,
    this.conseilValidation,
    this.coordoNotes,
    this.requestId,
  });

  /// Creer depuis un document Firestore
  factory UnifiedRequestModel.fromDocument(
    DocumentSnapshot doc, {
    RequestType type = RequestType.general,
  }) {
    if (!doc.exists) {
      throw Exception('Document requ ete introuvable');
    }
    final data = doc.data() as Map<String, dynamic>;
    return UnifiedRequestModel.fromMap(data, doc.id, type: type);
  }

  /// Creer depuis une Map
  factory UnifiedRequestModel.fromMap(
    Map<String, dynamic> map,
    String id, {
    RequestType type = RequestType.general,
  }) {
    return UnifiedRequestModel(
      id: id,
      titre: map['titre'] as String? ?? 'Sans titre',
      region: RegionUtils.normalize(map['region'] as String?),
      userId: map['userId'] as String? ?? '',
      userEmail: map['userEmail'] as String?,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']),
      type: type,
      statut: map['statut'] as String? ?? 'pending',
      memberStatus: map['memberStatus'] as String?,
      description: map['description'] as String?,
      localisation: map['localisation'] as String?,
      reason: map['reason'] as String?,
      studentBio: map['studentBio'] as String?,
      familySituation: map['familySituation'] as String?,
      montant: _parseDouble(map['montant']),
      montantAccorde: _parseDouble(map['montantAccorde']),
      pdfUrl: map['pdfUrl'] as String?,
      justificationUrl: map['justificationUrl'] as String?,
      adminValidation:
          map['adminValidatedAt'] != null || map['adminValidatedBy'] != null
          ? ValidationTimestamp(
              validatedAt: _parseDate(map['adminValidatedAt']),
              validatedBy: map['adminValidatedBy'] as String?,
            )
          : null,
      conseilValidation:
          map['conseilValidatedAt'] != null || map['conseilValidatedBy'] != null
          ? ValidationTimestamp(
              validatedAt: _parseDate(map['conseilValidatedAt']),
              validatedBy: map['conseilValidatedBy'] as String?,
            )
          : null,
      coordoNotes: map['coordoNotesAt'] != null || map['coordoNotesBy'] != null
          ? ValidationTimestamp(
              validatedAt: _parseDate(map['coordoNotesAt']),
              validatedBy: map['coordoNotesBy'] as String?,
              notes: map['coordoNotes'] as String?,
            )
          : null,
      requestId: map['requestId'] as String?,
    );
  }

  /// Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'titre': titre,
      'region': RegionUtils.normalize(region),
      'userId': userId,
      'userEmail': userEmail,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'type': type.toString().split('.').last,
      'statut': statut,
      'memberStatus': memberStatus,
      'description': description,
      'localisation': localisation,
      'reason': reason,
      'studentBio': studentBio,
      'familySituation': familySituation,
      'montant': montant,
      'montantAccorde': montantAccorde,
      'pdfUrl': pdfUrl,
      'justificationUrl': justificationUrl,
      'adminValidatedAt': adminValidation?.validatedAt,
      'adminValidatedBy': adminValidation?.validatedBy,
      'conseilValidatedAt': conseilValidation?.validatedAt,
      'conseilValidatedBy': conseilValidation?.validatedBy,
      'coordoNotes': coordoNotes?.notes,
      'coordoNotesAt': coordoNotes?.validatedAt,
      'coordoNotesBy': coordoNotes?.validatedBy,
      'requestId': requestId,
    };
  }

  // =====================================================
  // HELPER GETTERS
  // =====================================================

  bool get isApprovedByAdmin =>
      statut == 'approved_admin' ||
      statut == 'approved_council' ||
      statut == 'rejected';

  bool get isApprovedByCouncil => statut == 'approved_council';

  bool get isPending => statut == 'pending';

  bool get isRejected => statut == 'rejected';

  String get statusLabel {
    switch (statut) {
      case 'pending':
        return 'En attente';
      case 'approved_admin':
        return 'Approuvée (Admin)';
      case 'approved_council':
        return 'Approuvée (Conseil)';
      case 'rejected':
        return 'Rejetée';
      default:
        return 'Inconnu';
    }
  }

  // =====================================================
  // STATIC HELPERS
  // =====================================================

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
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
}

/// Type de requete
enum RequestType { general, sponsorship, validation }

/// Informations de validation avec timestamp
class ValidationTimestamp {
  final DateTime? validatedAt;
  final String? validatedBy;
  final String? notes;

  ValidationTimestamp({this.validatedAt, this.validatedBy, this.notes});

  bool get isValidated => validatedAt != null && validatedBy != null;

  String get formattedDate => validatedAt != null
      ? '${validatedAt!.day}/${validatedAt!.month}/${validatedAt!.year}'
      : 'N/A';
}
