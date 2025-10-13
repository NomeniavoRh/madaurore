import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String region;
  final String role;
  final String? photoUrl;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.region,
    required this.role,
    this.photoUrl,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      region: map['region'] as String? ?? '',
      role: map['role'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      status: map['status'] as String? ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    return UserModel.fromMap({'uid': doc.id, ...data});
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'region': region,
      'role': role,
      'photoUrl': photoUrl,
      'status': status,
    };
  }

  void operator [](String other) {}

  static UserModel? fromFirestore(Map<String, dynamic> map, String id) {
    return null;
  }
}
