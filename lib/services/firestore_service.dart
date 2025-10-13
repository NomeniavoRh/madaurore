import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/data/models/validation_request_model.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/models/sponsorship_request_model.dart';
import 'package:logger/logger.dart';

class FirestoreService {
  final logger = Logger();
  static final FirestoreService instance = FirestoreService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  FirestoreService._internal();

  // Ajouter un utilisateur dans 'users'
  Future<void> addUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
      logger.d('Utilisateur ajouté avec succès: ${user.uid}');
    } catch (e) {
      logger.e('Erreur lors de l\'ajout de l\'utilisateur: $e');
      rethrow;
    }
  }

  // Récupérer un utilisateur en temps réel
  Stream<UserModel> streamUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => UserModel.fromDocument(doc));
  }

  // Ajouter une demande générale dans 'requests' avec PDF
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
      final storageRef = _storage.ref().child('requests/$id.pdf');
      await storageRef.putFile(pdfFile);
      final pdfUrl = await storageRef.getDownloadURL();

      final request = RequestModel(
        id: id,
        titre: titre,
        statut: 'en attente',
        region: region,
        createdAt: Timestamp.now().toDate(), // Convertit Timestamp en DateTime
        userId: userId,
        localisation: localisation,
        pdfUrl: pdfUrl,
      );
      await _firestore.collection('requests').doc(id).set(request.toMap());
      logger.d('Demande générale ajoutée avec succès: $id');
    } catch (e) {
      logger.e('Erreur lors de l\'ajout de la demande: $e');
      rethrow;
    }
  }

  // Ajouter une demande de validation dans 'validation_requests'
  Future<void> addValidationRequest(
    ValidationRequestModel validationRequest,
  ) async {
    try {
      await _firestore
          .collection('validation_requests')
          .doc(validationRequest.id)
          .set(validationRequest.toMap());
      logger.d(
        'Demande de validation ajoutée avec succès: ${validationRequest.id}',
      );
    } catch (e) {
      logger.e('Erreur lors de l\'ajout de la demande de validation: $e');
      rethrow;
    }
  }

  // Mettre à jour une demande de validation
  Future<void> updateValidationRequest(String id, String status) async {
    try {
      await _firestore.collection('validation_requests').doc(id).update({
        'statut': status,
        'updatedAt': Timestamp.now()
            .toDate(), // Convertit Timestamp en DateTime
      });
      logger.d('Demande de validation mise à jour: $id');
    } catch (e) {
      logger.e('Erreur lors de la mise à jour: $e');
      rethrow;
    }
  }

  // Récupérer les demandes de validation en temps réel (filtré par région ou global pour admin)
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

  // Ajouter une demande de parrainage dans 'sponsorship_requests' avec PDF et justificatif
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

      final request = SponsorshipRequestModel(
        id: id,
        titre: titre,
        statut: 'en attente',
        region: region,
        createdAt: Timestamp.now().toDate(), // Convertit Timestamp en DateTime
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
      logger.d('Demande de parrainage ajoutée avec succès: $id');

      final validationRequest = ValidationRequestModel(
        id: 'val_$id',
        email: userEmail,
        region: region,
        statut: 'en attente',
        createdAt: Timestamp.now().toDate(), // Convertit Timestamp en DateTime
        requestId: id,
      );
      await addValidationRequest(validationRequest);
    } catch (e) {
      logger.e('Erreur lors de l\'ajout de la demande de parrainage: $e');
      rethrow;
    }
  }

  // Mettre à jour une demande de parrainage
  Future<void> updateSponsorshipRequest(
    String id,
    String status, {
    File? justificationFile,
  }) async {
    try {
      Map<String, dynamic> updatedData = {
        'statut': status,
        'updatedAt': Timestamp.now()
            .toDate(), // Convertit Timestamp en DateTime
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
      logger.d('Demande de parrainage mise à jour: $id');

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
      logger.e('Erreur lors de la mise à jour: $e');
      rethrow;
    }
  }

  // Récupérer les demandes de parrainage en temps réel
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

  // Récupérer les demandes d'un utilisateur en temps réel
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

  // Mettre à jour une demande (générique pour toutes les collections)
  Future<void> updateRequest(
    String requestId,
    String status, {
    File? justificationFile,
  }) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('sponsorship_requests')
          .doc(requestId)
          .get();
      if (doc.exists) {
        Map<String, dynamic> updatedData = {
          'statut': status,
          'updatedAt': Timestamp.now()
              .toDate(), // Convertit Timestamp en DateTime
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
        logger.d('Demande de parrainage mise à jour: $requestId');

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

      doc = await _firestore.collection('requests').doc(requestId).get();
      if (doc.exists) {
        Map<String, dynamic> updatedData = {
          'statut': status,
          'updatedAt': Timestamp.now()
              .toDate(), // Convertit Timestamp en DateTime
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
        logger.d('Demande générale mise à jour: $requestId');
        return;
      }

      throw Exception('Aucune demande trouvée avec l\'ID: $requestId');
    } catch (e) {
      logger.e('Erreur lors de la mise à jour de la demande: $e');
      rethrow;
    }
  }
}
