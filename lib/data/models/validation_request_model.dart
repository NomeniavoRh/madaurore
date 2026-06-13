import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:madaurore/core/utils/region_utils.dart';

class ValidationRequestModel {
  final String id;
  final String email;
  final String region;
  final String statut;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? requestId;

  ValidationRequestModel({
    required this.id,
    required this.email,
    required this.region,
    required this.statut,
    required this.createdAt,
    this.updatedAt,
    this.requestId,
  });

  factory ValidationRequestModel.fromMap(Map<String, dynamic> map) {
    final created = map['createdAt'];
    final updated = map['updatedAt'];
    DateTime createdAt;
    DateTime? updatedAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is DateTime) {
      createdAt = created;
    } else {
      createdAt = DateTime.now();
    }

    if (updated is Timestamp) {
      updatedAt = updated.toDate();
    } else if (updated is DateTime) {
      updatedAt = updated;
    } else {
      updatedAt = null;
    }

    return ValidationRequestModel(
      id: map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      region: RegionUtils.normalize(map['region'] as String?),
      statut: map['statut'] as String? ?? 'pending',
      createdAt: createdAt,
      updatedAt: updatedAt,
      requestId: map['requestId'] as String?,
    );
  }

  factory ValidationRequestModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    return ValidationRequestModel.fromMap({'id': doc.id, ...data});
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'region': RegionUtils.normalize(region),
      'statut': statut,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'requestId': requestId,
    };
  }
}
