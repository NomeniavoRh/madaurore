import 'package:cloud_firestore/cloud_firestore.dart';

class RequestModel {
  final String id;
  final String titre;
  final String statut; // 'en attente', 'approuve_admin', 'approuve_conseil', 'rejeté'
  final String region;
  final DateTime createdAt;
  final String userId;
  final String? localisation;
  final String? pdfUrl;
  final String? justificationUrl;
  final String? reason;
  
  // 🔑 CHAMPS FINANCIERS AJOUTÉS
  final double? montant;          // Montant demandé
  final double? montantAccorde;   // Montant approuvé par le Conseil
  final double? totalVerse;       // Total déjà versé (calculé côté client ou serveur)
  final double? solde;            // Solde restant (calculé)

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
    this.totalVerse,
    this.solde,
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
      statut: map['statut'] as String? ?? 'en attente',
      region: map['region'] as String? ?? '',
      createdAt: _parseDate(map['createdAt']),
      userId: map['userId'] as String? ?? '',
      localisation: map['localisation'] as String?,
      pdfUrl: map['pdfUrl'] as String?,
      justificationUrl: map['justificationUrl'] as String?,
      reason: map['reason'] as String?,
      // 🔑 PARSING DES CHAMPS FINANCIERS
      montant: (map['montant'] as num?)?.toDouble(),
      montantAccorde: (map['montantAccorde'] as num?)?.toDouble(),
      totalVerse: (map['totalVerse'] as num?)?.toDouble(),
      solde: (map['solde'] as num?)?.toDouble(),
    );
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is Timestamp) return date.toDate();
    if (date is DateTime) return date;
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (e) {
        return DateTime.now();
      }
    }
    if (date is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(date);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'titre': titre,
      'statut': statut,
      'region': region,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'localisation': localisation,
      'pdfUrl': pdfUrl,
      'justificationUrl': justificationUrl,
      'reason': reason,
      // LES CHAMPS FINANCIERS
      'montant': montant,
      'montantAccorde': montantAccorde,
      'totalVerse': totalVerse,
      'solde': solde,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  RequestModel copyWith({
    String? titre,
    String? statut,
    String? region,
    DateTime? createdAt,
    String? userId,
    String? localisation,
    String? pdfUrl,
    String? justificationUrl,
    String? reason,
    double? montant,
    double? montantAccorde,
    double? totalVerse,
    double? solde,
  }) {
    return RequestModel(
      id: id,
      titre: titre ?? this.titre,
      statut: statut ?? this.statut,
      region: region ?? this.region,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      localisation: localisation ?? this.localisation,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      justificationUrl: justificationUrl ?? this.justificationUrl,
      reason: reason ?? this.reason,
      montant: montant ?? this.montant,
      montantAccorde: montantAccorde ?? this.montantAccorde,
      totalVerse: totalVerse ?? this.totalVerse,
      solde: solde ?? this.solde,
    );
  }

  bool get isEnAttente => statut == 'en attente';
  bool get isApprouveAdmin => statut == 'approuve_admin';
  bool get isApprouveConseil => statut == 'approuve_conseil';
  bool get isRejete => statut == 'rejeté';
  bool get hasJustification => justificationUrl != null;

  @override
  String toString() {
    return 'RequestModel(id: $id, titre: $titre, statut: $statut, region: $region)';
  }
}