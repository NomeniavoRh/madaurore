import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/data/models/validation_request_model.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/models/sponsorship_request_model.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final logger = Logger();
  static final FirestoreService instance = FirestoreService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  FirestoreService._internal();

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
    required File pdfFile,
  }) async {
    try {
      final id = 'request_${DateTime.now().millisecondsSinceEpoch}';

      // Upload PDF
      final storageRef = _storage.ref().child('requests/$id.pdf');
      await storageRef.putFile(pdfFile);
      final pdfUrl = await storageRef.getDownloadURL();

      // ✅ CORRIGÉ: Créer avec Timestamp.now() au lieu de .toDate()
      final request = RequestModel(
        id: id,
        titre: titre,
        statut: 'en attente', // ✅ Statut initial correct
        region: region,
        createdAt: DateTime.now(), // ✅ DateTime.now() ici
        userId: userId,
        localisation: localisation,
        pdfUrl: pdfUrl,
        reason: reason, // ✅ Ajouter la raison
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
    File? justificationFile,
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
          await justificationStorageRef.putFile(justificationFile);
          updatedData['justificationUrl'] = await justificationStorageRef
              .getDownloadURL();
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
          await justificationStorageRef.putFile(justificationFile);
          updatedData['justificationUrl'] = await justificationStorageRef
              .getDownloadURL();
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
    Query query = _firestore
        .collection('validation_requests')
        .orderBy('createdAt', descending: true)
        .limit(20);

    if (region != null) {
      query = query.where('region', isEqualTo: region);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ValidationRequestModel.fromDocument(doc))
          .toList(),
    );
  }

  // ✅ CORRIGÉ: Ajouter une demande de parrainage
  Future<void> addSponsorshipRequest({
    required String titre,
    required String userId,
    required String userEmail,
    required String region,
    String? familySituation,
    required File pdfFile,
    required File justificationFile,
  }) async {
    try {
      final id = 'sponsorship_${DateTime.now().millisecondsSinceEpoch}';

      // Upload PDFs
      final requestStorageRef = _storage.ref().child(
        'sponsorship_requests/$id.pdf',
      );
      await requestStorageRef.putFile(pdfFile);
      final pdfUrl = await requestStorageRef.getDownloadURL();

      final justificationStorageRef = _storage.ref().child(
        'justifications/$id.pdf',
      );
      await justificationStorageRef.putFile(justificationFile);
      final justificationUrl = await justificationStorageRef.getDownloadURL();

      // ✅ CORRIGÉ: Utiliser DateTime.now()
      final request = SponsorshipRequestModel(
        id: id,
        titre: titre,
        statut: 'en attente',
        region: region,
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
        region: region,
        statut: 'en attente',
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
    File? justificationFile,
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
        await justificationStorageRef.putFile(justificationFile);
        updatedData['justificationUrl'] = await justificationStorageRef
            .getDownloadURL();
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
    Query query = _firestore
        .collection('sponsorship_requests')
        .orderBy('createdAt', descending: true)
        .limit(20);

    if (region != null) {
      query = query.where('region', isEqualTo: region);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => SponsorshipRequestModel.fromDocument(doc))
          .toList(),
    );
  }

  // ✅ Récupérer les demandes d'un utilisateur
  Stream<List<RequestModel>> streamRequestsForUser(String uid) {
    return _firestore
        .collection('requests')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RequestModel.fromDocument(doc))
              .toList(),
        );
  }
}
