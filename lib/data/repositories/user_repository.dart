import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:madaurore/core/utils/region_utils.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =====================================================
  // USERS
  // =====================================================

  /// Obtenir un utilisateur par ID
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists ? UserModel.fromDocument(doc) : null;
    } catch (e) {
      throw Exception('Erreur récupération utilisateur: $e');
    }
  }

  /// Stream d'un utilisateur
  Stream<UserModel?> getUserStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromDocument(doc) : null)
        .handleError((error) {
          throw Exception('Erreur stream utilisateur: $error');
        });
  }

  /// Stream des utilisateurs en attente (Admin)
  Stream<List<UserModel>> getPendingUsersStream() {
    return _firestore
        .collection('users')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromDocument(doc)).toList(),
        )
        .handleError((error) {
          throw Exception('Erreur stream utilisateurs en attente: $error');
        });
  }

  /// Obtenir tous les utilisateurs d'une région
  Future<List<UserModel>> getUsersByRegion(String region) async {
    try {
      final regions = RegionUtils.queryValues(region);
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .where('status', isEqualTo: 'approved');
      query = regions.length == 1
          ? query.where('region', isEqualTo: regions.first)
          : query.where('region', whereIn: regions);

      final snapshot = await query.get();

      return snapshot.docs.map((doc) => UserModel.fromDocument(doc)).toList();
    } catch (e) {
      throw Exception('Erreur récupération utilisateurs région: $e');
    }
  }

  /// Mettre à jour le statut d'un utilisateur (Admin)
  Future<void> updateUserStatus(String uid, String status) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'status': UserModel.normalizeStatus(status),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur mise à jour statut: $e');
    }
  }

  /// Mettre à jour le rôle d'un utilisateur (Admin)
  Future<void> updateUserRole(String uid, String role) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'role': UserModel.normalizeRole(role),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur mise à jour rôle: $e');
    }
  }

  /// Approuver un utilisateur (Admin)
  Future<void> approveUser(String uid) async {
    try {
      await updateUserStatus(uid, 'approved');
    } catch (e) {
      throw Exception('Erreur approbation utilisateur: $e');
    }
  }

  /// Rejeter un utilisateur (Admin)
  Future<void> rejectUser(String uid) async {
    try {
      await updateUserStatus(uid, 'rejected');
    } catch (e) {
      throw Exception('Erreur rejet utilisateur: $e');
    }
  }
}
