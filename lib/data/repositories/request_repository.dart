import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:madaurore/core/utils/member_status_utils.dart';
import 'package:madaurore/core/utils/region_utils.dart';
import '../models/request_model.dart';
import '../models/sponsorship_request_model.dart';
import '../models/validation_request_model.dart';

/// Repository centralisé pour la gestion des requêtes
/// Unifie les 3 collections Firestore : requests, sponsorship_requests, validation_requests
class RequestRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Query<Map<String, dynamic>> _baseRequestsQuery({
    String? region,
    String? userId,
    String? statut,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('requests');

    if (userId != null && userId.trim().isNotEmpty) {
      query = query.where('userId', isEqualTo: userId.trim());
    }

    if (region != null && region.trim().isNotEmpty) {
      final regions = RegionUtils.queryValues(region);
      query = regions.length == 1
          ? query.where('region', isEqualTo: regions.first)
          : query.where('region', whereIn: regions);
    }

    if (statut != null && statut.trim().isNotEmpty) {
      query = query.where('statut', isEqualTo: statut.trim());
    }

    return query;
  }

  List<RequestModel> _parseRequestSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    DateTime Function(RequestModel request)? sortDate,
  }) {
    final requests = <RequestModel>[];

    for (final doc in snapshot.docs) {
      try {
        requests.add(RequestModel.fromDocument(doc));
      } catch (e) {
        debugPrint('Erreur parsing request ${doc.id}: $e');
      }
    }

    requests.sort((a, b) {
      final left = sortDate?.call(a) ?? a.createdAt;
      final right = sortDate?.call(b) ?? b.createdAt;
      return right.compareTo(left);
    });

    return requests;
  }

  Stream<List<RequestModel>> watchRequests({
    String? region,
    String? userId,
    String? statut,
    int limit = 500,
    DateTime Function(RequestModel request)? sortDate,
  }) {
    return _baseRequestsQuery(region: region, userId: userId, statut: statut)
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => _parseRequestSnapshot(snapshot, sortDate: sortDate));
  }

  // =====================================================
  // REQUÊTES GÉNÉRALES (requests collection)
  // =====================================================

  /// Obtenir une requête par ID
  Future<RequestModel?> getRequestById(String requestId) async {
    try {
      final doc = await _firestore.collection('requests').doc(requestId).get();
      return doc.exists ? RequestModel.fromDocument(doc) : null;
    } catch (e) {
      throw Exception('Erreur récupération requête: $e');
    }
  }

  /// Stream d'une requête (mise à jour temps réel)
  Stream<RequestModel?> getRequestStream(String requestId) {
    return _firestore
        .collection('requests')
        .doc(requestId)
        .snapshots()
        .map((doc) => doc.exists ? RequestModel.fromDocument(doc) : null)
        .handleError((error) {
          throw Exception('Erreur stream requête: $error');
        });
  }

  /// Obtenir toutes les requêtes d'une région
  Stream<List<RequestModel>> getRequestsByRegionStream(
    String region, {
    int limit = 100,
  }) {
    return watchRequests(region: region, limit: limit).handleError((error) {
      throw Exception('Erreur stream requêtes région: $error');
    });
  }

  /// Obtenir les requêtes en attente d'une région
  Stream<List<RequestModel>> getPendingRequestsByRegionStream(
    String region, {
    int limit = 100,
  }) {
    return watchRequests(
      region: region,
      statut: 'pending',
      limit: limit,
    ).handleError((error) {
      throw Exception('Erreur stream requêtes en attente: $error');
    });
  }

  /// Obtenir les requêtes d'un utilisateur
  Stream<List<RequestModel>> getUserRequestsStream(
    String userId, {
    int limit = 100,
  }) {
    return watchRequests(userId: userId, limit: limit).handleError((error) {
      throw Exception('Erreur stream requêtes utilisateur: $error');
    });
  }

  /// Obtenir les requêtes approuvées par admin mais en attente du conseil
  Stream<List<RequestModel>> getPendingCouncilApprovalStream({
    int limit = 100,
  }) {
    return watchRequests(
      statut: 'approved_admin',
      limit: limit,
      sortDate: (request) => request.adminValidatedAt ?? request.createdAt,
    ).handleError((error) {
      throw Exception('Erreur stream requêtes en attente conseil: $error');
    });
  }

  /// Créer une nouvelle requête
  Future<String> createRequest(RequestModel request) async {
    try {
      final docRef = await _firestore.collection('requests').add({
        'titre': request.titre,
        'statut': request.statut,
        'region': RegionUtils.normalize(request.region),
        'userId': request.userId,
        'createdAt': FieldValue.serverTimestamp(),
        'localisation': request.localisation,
        'pdfUrl': request.pdfUrl,
        'justificationUrl': request.justificationUrl,
        'reason': request.reason,
        'montant': request.montant,
        'montantAccorde': request.montantAccorde,
        'studentBio': request.studentBio,
        'memberStatus': MemberStatusUtils.normalize(request.memberStatus),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Erreur création requête: $e');
    }
  }

  /// Mettre à jour le statut d'une requête
  Future<void> updateRequestStatus(String requestId, String newStatus) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'statut': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur mise à jour statut requête: $e');
    }
  }

  /// Valider une requête (Admin)
  Future<void> approveRequestAsAdmin(String requestId, String adminId) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'statut': 'approved_admin',
        'adminValidatedAt': FieldValue.serverTimestamp(),
        'adminValidatedBy': adminId,
      });
    } catch (e) {
      throw Exception('Erreur approbation admin: $e');
    }
  }

  /// Valider une requête (Conseil Administratif)
  Future<void> approveRequestAsCouncil(
    String requestId,
    String councilId,
  ) async {
    try {
      final doc = await _firestore.collection('requests').doc(requestId).get();
      if (!doc.exists) throw Exception('Requête non trouvée');

      final montantAccorde =
          (doc.data() as Map<String, dynamic>)['montantAccorde'] ?? 0.0;

      await _firestore.collection('requests').doc(requestId).update({
        'statut': 'approved_council',
        'conseilValidatedAt': FieldValue.serverTimestamp(),
        'conseilValidatedBy': councilId,
        'montantAccorde': montantAccorde,
      });
    } catch (e) {
      throw Exception('Erreur approbation conseil: $e');
    }
  }

  /// Rejeter une requête
  Future<void> rejectRequest(String requestId, String reason) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'statut': 'rejected',
        'reason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur rejet requête: $e');
    }
  }

  /// Ajouter des notes du coordinateur
  Future<void> addCoordinatorNotes(
    String requestId,
    String notes,
    String coordinatorId,
    String memberStatus,
  ) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'coordoNotes': notes,
        'coordoNotesAt': FieldValue.serverTimestamp(),
        'coordoNotesBy': coordinatorId,
        'memberStatus':
            MemberStatusUtils.normalize(memberStatus) ?? memberStatus,
      });
    } catch (e) {
      throw Exception('Erreur ajout notes coordo: $e');
    }
  }

  /// Mettre à jour les PDF/fichiers
  Future<void> updateRequestFiles(
    String requestId, {
    String? pdfUrl,
    String? justificationUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (pdfUrl != null) updateData['pdfUrl'] = pdfUrl;
      if (justificationUrl != null) {
        updateData['justificationUrl'] = justificationUrl;
      }

      await _firestore.collection('requests').doc(requestId).update(updateData);
    } catch (e) {
      throw Exception('Erreur mise à jour fichiers: $e');
    }
  }

  // =====================================================
  // REQUÊTES DE PARRAINAGE (sponsorship_requests collection)
  // =====================================================

  /// Obtenir les requêtes de parrainage d'une région
  Stream<List<SponsorshipRequestModel>> getSponsorshipRequestsByRegionStream(
    String region, {
    int limit = 100,
  }) {
    final regions = RegionUtils.queryValues(region);
    Query<Map<String, dynamic>> query = _firestore.collection(
      'sponsorship_requests',
    );
    query = regions.length == 1
        ? query.where('region', isEqualTo: regions.first)
        : query.where('region', whereIn: regions);

    return query
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => SponsorshipRequestModel.fromDocument(doc))
              .toList();
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return requests;
        })
        .handleError((error) {
          throw Exception('Erreur stream requêtes parrainage: $error');
        });
  }

  /// Créer une requête de parrainage
  Future<String> createSponsorshipRequest(
    SponsorshipRequestModel request,
  ) async {
    try {
      final docRef = await _firestore.collection('sponsorship_requests').add({
        'titre': request.titre,
        'statut': request.statut,
        'region': RegionUtils.normalize(request.region),
        'userId': request.userId,
        'userEmail': request.userEmail,
        'familySituation': request.familySituation,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Erreur création requête parrainage: $e');
    }
  }

  // =====================================================
  // REQUÊTES DE VALIDATION (validation_requests collection)
  // =====================================================

  /// Obtenir l'historique de validation
  Stream<List<ValidationRequestModel>> getValidationHistoryStream({
    int limit = 500,
  }) {
    return _firestore
        .collection('validation_requests')
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final records = snapshot.docs
              .map((doc) => ValidationRequestModel.fromDocument(doc))
              .toList();
          records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return records;
        })
        .handleError((error) {
          throw Exception('Erreur stream historique validation: $error');
        });
  }

  /// Obtenir l'historique de validation par région
  Stream<List<ValidationRequestModel>> getValidationHistoryByRegionStream(
    String region, {
    int limit = 500,
  }) {
    final regions = RegionUtils.queryValues(region);
    Query<Map<String, dynamic>> query = _firestore.collection(
      'validation_requests',
    );
    query = regions.length == 1
        ? query.where('region', isEqualTo: regions.first)
        : query.where('region', whereIn: regions);

    return query
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final records = snapshot.docs
              .map((doc) => ValidationRequestModel.fromDocument(doc))
              .toList();
          records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return records;
        })
        .handleError((error) {
          throw Exception('Erreur stream validation région: $error');
        });
  }

  /// Créer une trace de validation
  Future<String> createValidationRecord(
    ValidationRequestModel validationRecord,
  ) async {
    try {
      final docRef = await _firestore.collection('validation_requests').add({
        'email': validationRecord.email,
        'region': RegionUtils.normalize(validationRecord.region),
        'statut': validationRecord.statut,
        'requestId': validationRecord.requestId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Erreur création trace validation: $e');
    }
  }

  /// Obtenir les statistiques globales des requêtes
  Future<Map<String, int>> getRequestGlobalStats() async {
    try {
      final snapshot = await _firestore.collection('requests').get();

      final stats = {
        'total': 0,
        'pending': 0,
        'approved_admin': 0,
        'approved_council': 0,
        'rejected': 0,
      };

      for (final doc in snapshot.docs) {
        final data = doc.data();
        stats['total'] = (stats['total'] ?? 0) + 1;

        final statut = data['statut'] as String? ?? '';
        switch (statut) {
          case 'pending':
            stats['pending'] = (stats['pending'] ?? 0) + 1;
            break;
          case 'approved_admin':
            stats['approved_admin'] = (stats['approved_admin'] ?? 0) + 1;
            break;
          case 'approved_council':
            stats['approved_council'] = (stats['approved_council'] ?? 0) + 1;
            break;
          case 'rejected':
            stats['rejected'] = (stats['rejected'] ?? 0) + 1;
            break;
        }
      }

      return stats;
    } catch (e) {
      throw Exception('Erreur calcul stats: $e');
    }
  }

  /// Supprimer une requête (Admin only)
  Future<void> deleteRequest(String requestId) async {
    try {
      await _firestore.collection('requests').doc(requestId).delete();
    } catch (e) {
      throw Exception('Erreur suppression requête: $e');
    }
  }
}
