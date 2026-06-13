import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:madaurore/core/utils/member_status_utils.dart';
import 'package:madaurore/core/utils/region_utils.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/data/models/validation_request_model.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/models/sponsorship_request_model.dart';
import 'package:madaurore/data/repositories/request_repository.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final logger = Logger();
  static final FirestoreService instance = FirestoreService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  FirestoreService._internal();

  static const int _maxPdfBytes = 10 * 1024 * 1024;

  Future<Uint8List> _readUploadBytes(Object file) async {
    if (file is PlatformFile) {
      if (file.bytes != null) return file.bytes!;
      if (file.readStream != null) {
        final chunks = <int>[];
        await for (final chunk in file.readStream!) {
          chunks.addAll(chunk);
        }
        return Uint8List.fromList(chunks);
      }
    }

    final bytes = await (file as dynamic).readAsBytes();
    if (bytes is Uint8List) return bytes;
    if (bytes is List<int>) return Uint8List.fromList(bytes);
    throw Exception('Fichier PDF illisible');
  }

  Future<String> _uploadPdf(Reference storageRef, Object file) async {
    final bytes = await _readUploadBytes(file);
    if (bytes.lengthInBytes > _maxPdfBytes) {
      throw Exception('Fichier trop volumineux, maximum 10 Mo');
    }

    final task = await storageRef.putData(
      bytes,
      SettableMetadata(contentType: 'application/pdf'),
    );
    return task.ref.getDownloadURL();
  }

  // ✅ Ajouter un utilisateur dans 'users'
  Future<void> addUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
      logger.d('✅ Utilisateur ajouté: ${user.uid}');
    } catch (e) {
      logger.e('❌ Erreur ajout utilisateur: $e');
      rethrow;
    }
  }

  // ✅ Récupérer un utilisateur en temps réel
  Stream<UserModel> streamUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => UserModel.fromDocument(doc));
  }

  // ✅ CORRIGÉ: Ajouter une demande générale dans 'requests'
  Future<void> addRequest({
    required String titre,
    required String reason,
    required String userId,
    required String region,
    String? localisation,
    double? montant,
    required Object pdfFile,
  }) async {
    try {
      final id = 'request_${DateTime.now().millisecondsSinceEpoch}';
      final normalizedRegion = RegionUtils.normalize(region);

      // Upload PDF
      final storageRef = _storage.ref().child('requests/$id.pdf');
      final pdfUrl = await _uploadPdf(storageRef, pdfFile);

      // ✅ CORRIGÉ: Créer avec Timestamp.now() au lieu de .toDate()
      final request = RequestModel(
        id: id,
        titre: titre,
        statut: 'pending',
        region: normalizedRegion,
        createdAt: DateTime.now(), // ✅ DateTime.now() ici
        userId: userId,
        localisation: localisation,
        pdfUrl: pdfUrl,
        reason: reason, // ✅ Ajouter la raison
        montant: montant,
      );

      // ✅ CORRIGÉ: Utiliser toMap() qui gère Timestamp correctement
      await _firestore.collection('requests').doc(id).set(request.toMap());

      logger.d('✅ Demande créée: $id (statut=en attente)');
    } catch (e) {
      logger.e('❌ Erreur ajout demande: $e');
      rethrow;
    }
  }

  // ✅ CORRIGÉ: Mettre à jour une demande
  Future<void> updateRequest(
    String requestId,
    String status, {
    Object? justificationFile,
  }) async {
    try {
      debugPrint('[updateRequest] ID: $requestId, Nouveau statut: $status');

      // Chercher dans 'sponsorship_requests' d'abord
      DocumentSnapshot doc = await _firestore
          .collection('sponsorship_requests')
          .doc(requestId)
          .get();

      if (doc.exists) {
        debugPrint('[updateRequest] Trouvé dans sponsorship_requests');

        Map<String, dynamic> updatedData = {
          'statut': status,
          'updatedAt': FieldValue.serverTimestamp(), // ✅ CORRIGÉ!
        };

        if (justificationFile != null) {
          final justificationStorageRef = _storage.ref().child(
            'justifications/$requestId.pdf',
          );
          updatedData['justificationUrl'] = await _uploadPdf(
            justificationStorageRef,
            justificationFile,
          );
        }

        await _firestore
            .collection('sponsorship_requests')
            .doc(requestId)
            .update(updatedData);

        logger.d('✅ sponsorship_requests mis à jour: $requestId');

        // Mettre à jour aussi validation_requests
        final validationQuery = await _firestore
            .collection('validation_requests')
            .where('requestId', isEqualTo: requestId)
            .limit(1)
            .get();

        if (validationQuery.docs.isNotEmpty) {
          final validationId = validationQuery.docs.first.id;
          await updateValidationRequest(validationId, status);
        }
        return;
      }

      // Chercher dans 'requests'
      doc = await _firestore.collection('requests').doc(requestId).get();

      if (doc.exists) {
        debugPrint('[updateRequest] Trouvé dans requests');

        Map<String, dynamic> updatedData = {
          'statut': status,
          'updatedAt': FieldValue.serverTimestamp(), // ✅ CORRIGÉ!
        };

        if (justificationFile != null) {
          final justificationStorageRef = _storage.ref().child(
            'justifications/$requestId.pdf',
          );
          updatedData['justificationUrl'] = await _uploadPdf(
            justificationStorageRef,
            justificationFile,
          );
        }

        await _firestore
            .collection('requests')
            .doc(requestId)
            .update(updatedData);

        logger.d('✅ requests mis à jour: $requestId (statut=$status)');
        return;
      }

      throw Exception('❌ Demande introuvable: $requestId');
    } catch (e) {
      logger.e('❌ Erreur mise à jour: $e');
      rethrow;
    }
  }

  Future<void> uploadRequestJustification({
    required String requestId,
    required Object justificationFile,
  }) async {
    try {
      final doc = await _firestore.collection('requests').doc(requestId).get();
      if (!doc.exists) {
        throw Exception('Demande introuvable');
      }

      final data = doc.data() as Map<String, dynamic>;
      if (data['statut'] != 'approved_council') {
        throw Exception(
          'Les justificatifs peuvent être envoyés après validation du Conseil',
        );
      }

      final justificationStorageRef = _storage.ref().child(
        'justifications/$requestId.pdf',
      );
      final url = await _uploadPdf(justificationStorageRef, justificationFile);

      await _firestore.collection('requests').doc(requestId).update({
        'justificationUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      logger.d('✅ Justificatif mis à jour: $requestId');
    } catch (e) {
      logger.e('❌ Erreur upload justificatif: $e');
      rethrow;
    }
  }

  // ✅ CORRIGÉ: Mettre à jour une demande de validation
  Future<void> updateValidationRequest(String id, String status) async {
    try {
      await _firestore.collection('validation_requests').doc(id).update({
        'statut': status,
        'updatedAt': FieldValue.serverTimestamp(), // ✅ CORRIGÉ!
      });
      logger.d('✅ Validation request mis à jour: $id');
    } catch (e) {
      logger.e('❌ Erreur validation request: $e');
      rethrow;
    }
  }

  // ✅ Récupérer les demandes de validation
  Stream<List<ValidationRequestModel>> streamValidationRequests(
    String? region,
  ) {
    if (region != null) {
      return RequestRepository().getValidationHistoryByRegionStream(
        region,
        limit: 50,
      );
    }

    return _firestore
        .collection('validation_requests')
        .limit(50)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final records = snapshot.docs
              .map((doc) => ValidationRequestModel.fromDocument(doc))
              .toList();
          records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return records;
        });
  }

  // ✅ CORRIGÉ: Ajouter une demande de parrainage
  Future<void> addSponsorshipRequest({
    required String titre,
    required String userId,
    required String userEmail,
    required String region,
    String? familySituation,
    required Object pdfFile,
    required Object justificationFile,
  }) async {
    try {
      final id = 'sponsorship_${DateTime.now().millisecondsSinceEpoch}';
      final normalizedRegion = RegionUtils.normalize(region);

      // Upload PDFs
      final requestStorageRef = _storage.ref().child(
        'sponsorship_requests/$id.pdf',
      );
      final pdfUrl = await _uploadPdf(requestStorageRef, pdfFile);

      final justificationStorageRef = _storage.ref().child(
        'justifications/$id.pdf',
      );
      final justificationUrl = await _uploadPdf(
        justificationStorageRef,
        justificationFile,
      );

      // ✅ CORRIGÉ: Utiliser DateTime.now()
      final request = SponsorshipRequestModel(
        id: id,
        titre: titre,
        statut: 'pending',
        region: normalizedRegion,
        createdAt: DateTime.now(), // ✅ CORRIGÉ!
        familySituation: familySituation,
        userId: userId,
        userEmail: userEmail,
        pdfUrl: pdfUrl,
        justificationUrl: justificationUrl,
      );

      await _firestore
          .collection('sponsorship_requests')
          .doc(id)
          .set(request.toMap());

      logger.d('✅ Sponsorship request créé: $id');

      // Créer aussi une validation request
      final validationRequest = ValidationRequestModel(
        id: 'val_$id',
        email: userEmail,
        region: normalizedRegion,
        statut: 'pending',
        createdAt: DateTime.now(), // ✅ CORRIGÉ!
        requestId: id,
      );

      await addValidationRequest(validationRequest);
    } catch (e) {
      logger.e('❌ Erreur sponsorship: $e');
      rethrow;
    }
  }

  // ✅ Ajouter une demande de validation
  Future<void> addValidationRequest(
    ValidationRequestModel validationRequest,
  ) async {
    try {
      await _firestore
          .collection('validation_requests')
          .doc(validationRequest.id)
          .set(validationRequest.toMap());
      logger.d('✅ Validation request ajouté: ${validationRequest.id}');
    } catch (e) {
      logger.e('❌ Erreur validation: $e');
      rethrow;
    }
  }

  // ✅ CORRIGÉ: Mettre à jour une demande de parrainage
  Future<void> updateSponsorshipRequest(
    String id,
    String status, {
    Object? justificationFile,
  }) async {
    try {
      Map<String, dynamic> updatedData = {
        'statut': status,
        'updatedAt': FieldValue.serverTimestamp(), // ✅ CORRIGÉ!
      };

      if (justificationFile != null) {
        final justificationStorageRef = _storage.ref().child(
          'justifications/$id.pdf',
        );
        updatedData['justificationUrl'] = await _uploadPdf(
          justificationStorageRef,
          justificationFile,
        );
      }

      await _firestore
          .collection('sponsorship_requests')
          .doc(id)
          .update(updatedData);

      logger.d('✅ Sponsorship request mis à jour: $id');

      // Mettre à jour aussi validation_requests
      final validationQuery = await _firestore
          .collection('validation_requests')
          .where('requestId', isEqualTo: id)
          .limit(1)
          .get();

      if (validationQuery.docs.isNotEmpty) {
        final validationId = validationQuery.docs.first.id;
        await updateValidationRequest(validationId, status);
      }
    } catch (e) {
      logger.e('❌ Erreur update sponsorship: $e');
      rethrow;
    }
  }

  // ✅ Récupérer les demandes de parrainage
  Stream<List<SponsorshipRequestModel>> streamSponsorshipRequests(
    String? region,
  ) {
    if (region != null) {
      return RequestRepository().getSponsorshipRequestsByRegionStream(
        region,
        limit: 50,
      );
    }

    return _firestore
        .collection('sponsorship_requests')
        .limit(50)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => SponsorshipRequestModel.fromDocument(doc))
              .toList();
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return requests;
        });
  }

  // ✅ Récupérer les demandes d'un utilisateur
  Stream<List<RequestModel>> streamRequestsForUser(String uid) {
    return RequestRepository().getUserRequestsStream(uid, limit: 50);
  }
  // =====================================================
  // COORDO NOTES (NOUVEAU)
  // =====================================================

  /// Ajouter les notes du coordo régional
  Future<void> addCoordonotes({
    required String requestId,
    required String memberStatus, // 'nouveau_membre' ou 'ancien_membre'
    required String notes,
    required String coordoId,
    required String coordoName,
  }) async {
    try {
      await _saveCoordinatorMemberStatus(
        requestId: requestId,
        memberStatus: memberStatus,
        notes: notes,
        coordoId: coordoId,
      );

      logger.d(
        '✅ Notes du coordo ajoutées: $requestId (status: $memberStatus)',
      );
    } catch (e) {
      logger.e('❌ Erreur ajout notes coordo: $e');
      rethrow;
    }
  }

  /// Mettre à jour les notes du coordo
  Future<void> updateCoordonotes({
    required String requestId,
    required String memberStatus,
    required String notes,
    required String coordoId,
  }) async {
    try {
      await _saveCoordinatorMemberStatus(
        requestId: requestId,
        memberStatus: memberStatus,
        notes: notes,
        coordoId: coordoId,
      );

      logger.d('✅ Notes du coordo mises à jour: $requestId');
    } catch (e) {
      logger.e('❌ Erreur mise à jour notes: $e');
      rethrow;
    }
  }

  Future<void> _saveCoordinatorMemberStatus({
    required String requestId,
    required String memberStatus,
    required String notes,
    required String coordoId,
  }) async {
    final normalizedStatus =
        MemberStatusUtils.normalize(memberStatus) ??
        MemberStatusUtils.unclassified;
    final requestRef = _firestore.collection('requests').doc(requestId);
    final requestSnapshot = await requestRef.get();
    final userId = requestSnapshot.data()?['userId'] as String?;
    final batch = _firestore.batch();

    batch.update(requestRef, {
      'memberStatus': normalizedStatus,
      'coordoNotes': notes,
      'coordoNotesAt': FieldValue.serverTimestamp(),
      'coordoNotesBy': coordoId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (userId != null && userId.trim().isNotEmpty) {
      batch.update(_firestore.collection('users').doc(userId), {
        'memberStatus': normalizedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
