import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:madaurore/core/utils/member_status_utils.dart';
import 'package:madaurore/core/utils/region_utils.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String region;
  // student, regional_coordinator, admin, Conseil_Administratif
  final String role;
  final String status; // pending, approved, rejected
  final DateTime createdAt;
  final String? photoUrl;
  final String? memberStatus;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required String region,
    required String role,
    required String status,
    required this.createdAt,
    this.photoUrl,
    String? memberStatus,
  }) : region = RegionUtils.normalize(region),
       role = normalizeRole(role),
       status = normalizeStatus(status),
       memberStatus = MemberStatusUtils.normalize(memberStatus);

  factory UserModel.fromDocument(DocumentSnapshot doc) {
    if (!doc.exists) {
      throw Exception('Document utilisateur introuvable');
    }
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id);
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    final role = normalizeRole(map['role'] as String?);
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      fullName: map['fullName'] as String? ?? 'Utilisateur',
      region: RegionUtils.normalize(map['region'] as String?),
      role: role,
      status: normalizeStatus(map['status'] as String?),
      createdAt: _parseDate(map['createdAt']),
      photoUrl: map['photoUrl'] as String?,
      memberStatus: MemberStatusUtils.normalize(
        map['memberStatus'] as String? ??
            (role == 'student' ? MemberStatusUtils.newMember : null),
      ),
    );
  }

  static String normalizeRole(String? role) {
    final value = role?.trim();
    if (value == null || value.isEmpty) return 'student';

    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .replaceAll('__', '_');

    switch (normalized) {
      case 'admin':
      case 'administrator':
      case 'administrateur':
        return 'admin';
      case 'regional_coordinator':
      case 'coordinateur':
      case 'coordinateur_regional':
      case 'coordinator':
      case 'coordo':
        return 'regional_coordinator';
      case 'conseil_administratif':
      case 'conseil_admin':
      case 'conseil':
      case 'council':
      case 'council_admin':
        return 'Conseil_Administratif';
      case 'student':
      case 'etudiant':
      case 'etudiante':
        return 'student';
      default:
        return value;
    }
  }

  static String normalizeStatus(String? status) {
    final value = status?.trim();
    if (value == null || value.isEmpty) return 'pending';

    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .replaceAll('__', '_');

    switch (normalized) {
      case 'approved':
      case 'active':
      case 'actif':
      case 'valide':
      case 'validated':
        return 'approved';
      case 'pending':
      case 'waiting':
      case 'en_attente':
        return 'pending';
      case 'rejected':
      case 'reject':
      case 'refused':
      case 'refuse':
        return 'rejected';
      default:
        return value;
    }
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) {
      return DateTime.now();
    }
    if (date is Timestamp) {
      return date.toDate();
    }
    if (date is DateTime) {
      return date;
    }
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
      'email': email,
      'fullName': fullName,
      'region': RegionUtils.normalize(region),
      'role': normalizeRole(role),
      'status': normalizeStatus(status),
      'createdAt': Timestamp.fromDate(createdAt),
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
      'memberStatus': MemberStatusUtils.normalize(memberStatus),
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
    String? memberStatus,
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
      memberStatus: memberStatus ?? this.memberStatus,
    );
  }

  // ✅ GETTERS POUR VÉRIFICATIONS
  bool get isApproved => status == 'approved';
  bool get isStudent => role == 'student';
  bool get isRegionalCoordinator => role == 'regional_coordinator';
  bool get isAdmin => role == 'admin';
  bool get isConseilAdministratif => role == 'Conseil_Administratif';
  bool get isManager =>
      isRegionalCoordinator || isAdmin || isConseilAdministratif;

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
