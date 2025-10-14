import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String region;
  final String role; // 'student', 'regional_coordinator', 'admin'
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final String? photoUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.region,
    required this.role,
    required this.status,
    required this.createdAt,
    this.photoUrl,
  });

  // =====================================================
  // CRÉATION DEPUIS FIRESTORE DOCUMENT
  // =====================================================
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    // Vérifier que le document existe
    if (!doc.exists) {
      throw Exception('Document utilisateur introuvable');
    }

    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id);
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,

      // Email avec valeur par défaut
      email: map['email'] as String? ?? '',

      // Nom complet avec valeur par défaut
      fullName: map['fullName'] as String? ?? 'Utilisateur',

      // Région avec valeur par défaut
      region: map['region'] as String? ?? 'Antananarivo',

      // Rôle avec valeur par défaut
      role: map['role'] as String? ?? 'student',

      // Statut avec valeur par défaut
      status: map['status'] as String? ?? 'pending',

      // Date de création (avec parsing sécurisé)
      createdAt: _parseDate(map['createdAt']),

      // Photo (peut être null)
      photoUrl: map['photoUrl'] as String?,
    );
  }

  static DateTime _parseDate(dynamic date) {
    // Si null, retourner maintenant
    if (date == null) {
      return DateTime.now();
    }

    // Si c'est un Timestamp Firestore
    if (date is Timestamp) {
      return date.toDate();
    }

    // Si c'est déjà un DateTime
    if (date is DateTime) {
      return date;
    }

    // Si c'est une String (format ISO)
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (e) {
        return DateTime.now();
      }
    }

    // Si c'est un int (milliseconds depuis epoch)
    if (date is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(date);
      } catch (e) {
        return DateTime.now();
      }
    }

    // Cas par défaut
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'region': region,
      'role': role,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? email,
    String? fullName,
    String? region,
    String? role,
    String? status,
    DateTime? createdAt,
    String? photoUrl,
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      region: region ?? this.region,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  // Vérifier si l'utilisateur est approuvé
  bool get isApproved => status == 'approved';

  // Vérifier si l'utilisateur est admin
  bool get isAdmin => role == 'admin';

  // Vérifier si l'utilisateur est coordinateur
  bool get isCoordinator => role == 'regional_coordinator';

  // Vérifier si l'utilisateur est étudiant
  bool get isStudent => role == 'student';

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, fullName: $fullName, '
        'region: $region, role: $role, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserModel &&
        other.uid == uid &&
        other.email == email &&
        other.fullName == fullName &&
        other.region == region &&
        other.role == role &&
        other.status == status;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        email.hashCode ^
        fullName.hashCode ^
        region.hashCode ^
        role.hashCode ^
        status.hashCode;
  }
}
