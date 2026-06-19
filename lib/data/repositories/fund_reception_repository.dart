import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:madaurore/core/utils/region_utils.dart';
import 'package:madaurore/data/models/fund_reception_model.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/models/user_model.dart';

class FundReceptionRepository {
  FundReceptionRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const int maxFileBytes = 10 * 1024 * 1024;

  Query<Map<String, dynamic>> _baseQueryForRequest(String requestId) {
    return _firestore
        .collection('fund_receptions')
        .where('requestId', isEqualTo: requestId);
  }

  Stream<List<FundReceptionModel>> watchForRequest({
    required String requestId,
    required UserModel currentUser,
    required String requestRegion,
  }) {
    Query<Map<String, dynamic>> query = _baseQueryForRequest(requestId);

    if (currentUser.isStudent) {
      query = query.where('userId', isEqualTo: currentUser.uid);
    } else if (currentUser.isRegionalCoordinator) {
      query = query.where(
        'region',
        isEqualTo: RegionUtils.normalize(requestRegion),
      );
    }

    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      final receptions = snapshot.docs
          .map((doc) => FundReceptionModel.fromDocument(doc))
          .toList();
      receptions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return receptions;
    });
  }

  Future<List<FundReceptionModel>> fetchForRequest(String requestId) async {
    final snapshot = await _baseQueryForRequest(requestId).get();
    final receptions = snapshot.docs
        .map((doc) => FundReceptionModel.fromDocument(doc))
        .toList();
    receptions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return receptions;
  }

  Future<void> addReceptionProof({
    required RequestModel request,
    required UserModel student,
    required PlatformFile file,
    required double amount,
    required DateTime receivedDate,
    String? note,
  }) async {
    if (!student.isStudent || request.userId != student.uid) {
      throw Exception(
        'Seul l\'etudiant concerne peut confirmer la reception de l\'aide',
      );
    }
    if (!request.isApprouveConseil) {
      throw Exception(
        'La reception de l\'aide peut etre confirmee apres validation du Conseil',
      );
    }
    if (amount <= 0) {
      throw Exception('Montant recu invalide');
    }

    final grantedAmount = request.montantAccorde ?? request.montant ?? 0;
    if (grantedAmount <= 0) {
      throw Exception('Aucun montant accorde pour cette demande');
    }

    final existingReceptions = await fetchForRequest(request.id);
    final declaredReceived = existingReceptions
        .where((item) => !item.isRejected && !item.needsCorrection)
        .fold<double>(0, (sum, item) => sum + item.amount);

    if (declaredReceived + amount > grantedAmount + 0.001) {
      throw Exception(
        'Le total recu depasse le montant accorde pour cette demande',
      );
    }

    final bytes = await _readUploadBytes(file);
    if (bytes.lengthInBytes > maxFileBytes) {
      throw Exception('Fichier trop volumineux, maximum 10 Mo');
    }

    final docRef = _firestore.collection('fund_receptions').doc();
    final safeFileName = _safeFileName(file.name);
    final contentType = _contentTypeFor(safeFileName);
    final storageRef = _storage.ref().child(
      'fund_receptions/${student.uid}/${request.id}/${docRef.id}_$safeFileName',
    );

    final upload = await storageRef.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'requestId': request.id,
          'userId': student.uid,
          'originalName': file.name,
        },
      ),
    );
    final fileUrl = await upload.ref.getDownloadURL();
    final timestamp = FieldValue.serverTimestamp();
    final cleanNote = note?.trim();

    await docRef.set({
      'requestId': request.id,
      'userId': student.uid,
      'region': RegionUtils.normalize(request.region),
      'amount': amount,
      'receivedDate': Timestamp.fromDate(receivedDate),
      'note': cleanNote == null || cleanNote.isEmpty ? null : cleanNote,
      'fileUrl': fileUrl,
      'fileName': file.name,
      'fileSize': bytes.lengthInBytes,
      'contentType': contentType,
      'status': 'pending',
      'createdAt': timestamp,
      'uploadAt': timestamp,
      'updatedAt': timestamp,
    });
  }

  Future<void> reviewReception({
    required String receptionId,
    required String status,
    required UserModel reviewer,
    String? rejectionReason,
  }) async {
    final normalizedStatus = FundReceptionModel.normalizeStatus(status);
    if (!const {
      'approved',
      'rejected',
      'needs_correction',
    }.contains(normalizedStatus)) {
      throw Exception('Statut de validation invalide');
    }

    await _firestore.collection('fund_receptions').doc(receptionId).update({
      'status': normalizedStatus,
      'reviewedBy': reviewer.uid,
      'reviewerName': reviewer.fullName,
      'reviewedAt': FieldValue.serverTimestamp(),
      'rejectionReason': normalizedStatus == 'approved'
          ? null
          : rejectionReason?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Uint8List> _readUploadBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.readStream != null) {
      final chunks = <int>[];
      await for (final chunk in file.readStream!) {
        chunks.addAll(chunk);
      }
      return Uint8List.fromList(chunks);
    }
    throw Exception('Fichier illisible depuis le navigateur');
  }

  String _safeFileName(String fileName) {
    final fallback = fileName.trim().isEmpty ? 'reception.pdf' : fileName;
    return fallback.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'application/octet-stream';
  }
}
