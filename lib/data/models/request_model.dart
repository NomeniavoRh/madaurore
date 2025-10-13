import 'package:cloud_firestore/cloud_firestore.dart';

class RequestModel {
  final String id;
  final String titre;
  final String statut;
  final String region;
  final DateTime createdAt;
  final String? justificationUrl;
  final String userId;
  final String? detailFileUrl; // ← Ajout : URL Word détails
  final String? justificatifFileUrl; // ← Ajout : URL PDF justificatif

  RequestModel({
    required this.id,
    required this.titre,
    required this.statut,
    required this.region,
    required this.createdAt,
    this.justificationUrl,
    required this.userId,
    this.detailFileUrl,
    this.justificatifFileUrl,
    String? localisation,
    required String pdfUrl,
  });

  factory RequestModel.fromMap(Map<String, dynamic> map) {
    final created = map['createdAt'];
    DateTime createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is DateTime) {
      createdAt = created;
    } else {
      createdAt = DateTime.now();
    }
    return RequestModel(
      id: map['id'] as String? ?? '',
      titre: map['titre'] as String? ?? '',
      statut: map['statut'] as String? ?? 'pending',
      region: map['region'] as String? ?? '',
      createdAt: createdAt,
      justificationUrl: map['justificationUrl'] as String?,
      userId: map['userId'] as String? ?? '',
      detailFileUrl: map['detailFileUrl'] as String?, // ← Nouveau
      justificatifFileUrl: map['justificatifFileUrl'] as String?, // ← Nouveau
      pdfUrl: '',
    );
  }

  factory RequestModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    return RequestModel.fromMap({'id': doc.id, ...data});
  }

  Map<String, dynamic> toMap() {
    return {
      'titre': titre,
      'statut': statut,
      'region': region,
      'createdAt': createdAt,
      'justificationUrl': justificationUrl,
      'userId': userId,
      'detailFileUrl': detailFileUrl, // ← Nouveau
      'justificatifFileUrl': justificatifFileUrl, // ← Nouveau
    };
  }
}
