import 'package:cloud_firestore/cloud_firestore.dart';

class StudentProfileModel {
  final String userId;
  final String bio;
  final DateTime createdAt;
  final DateTime? updatedAt;

  StudentProfileModel({
    required this.userId,
    required this.bio,
    required this.createdAt,
    this.updatedAt,
  });

  factory StudentProfileModel.fromDocument(DocumentSnapshot doc) {
    if (!doc.exists) {
      throw Exception('Profil étudiant introuvable');
    }
    final data = doc.data() as Map<String, dynamic>;
    return StudentProfileModel.fromMap(data, doc.id);
  }

  factory StudentProfileModel.fromMap(Map<String, dynamic> map, String userId) {
    return StudentProfileModel(
      userId: userId,
      bio: map['bio'] as String? ?? '',
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']),
    );
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
      'bio': bio,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  StudentProfileModel copyWith({String? bio}) {
    return StudentProfileModel(
      userId: userId,
      bio: bio ?? this.bio,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'StudentProfileModel(userId: $userId, bio: $bio)';
  }
}
