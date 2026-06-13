import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:madaurore/core/utils/region_utils.dart';

class SponsorshipRequestModel {
  final String id;
  final String titre;
  final String statut;
  final String region;
  final DateTime createdAt;
  final String? familySituation;
  final String userId;
  final String userEmail;
  final String? pdfUrl;
  final String? justificationUrl;

  SponsorshipRequestModel({
    required this.id,
    required this.titre,
    required this.statut,
    required this.region,
    required this.createdAt,
    this.familySituation,
    required this.userId,
    required this.userEmail,
    this.pdfUrl,
    this.justificationUrl,
  });

  factory SponsorshipRequestModel.fromMap(Map<String, dynamic> map) {
    final created = map['createdAt'];
    DateTime createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is DateTime) {
      createdAt = created;
    } else {
      createdAt = DateTime.now();
    }
    return SponsorshipRequestModel(
      id: map['id'] as String? ?? '',
      titre: map['titre'] as String? ?? '',
      statut: map['statut'] as String? ?? 'pending',
      region: RegionUtils.normalize(map['region'] as String?),
      createdAt: createdAt,
      familySituation: map['familySituation'] as String?,
      userId: map['userId'] as String? ?? '',
      userEmail: map['userEmail'] as String? ?? '',
      pdfUrl: map['pdfUrl'] as String?,
      justificationUrl: map['justificationUrl'] as String?,
    );
  }

  factory SponsorshipRequestModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    return SponsorshipRequestModel.fromMap({'id': doc.id, ...data});
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titre': titre,
      'statut': statut,
      'region': RegionUtils.normalize(region),
      'createdAt': createdAt,
      'familySituation': familySituation,
      'userId': userId,
      'userEmail': userEmail,
      'pdfUrl': pdfUrl,
      'justificationUrl': justificationUrl,
    };
  }
}
