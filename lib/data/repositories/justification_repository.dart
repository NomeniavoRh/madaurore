import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:madaurore/core/utils/region_utils.dart';
import 'package:madaurore/data/models/justification_model.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/models/user_model.dart';

class JustificationRepository {
  JustificationRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const int maxFileBytes = 10 * 1024 * 1024;

  Stream<List<JustificationModel>> watchForRequest({
    required String requestId,
    required UserModel currentUser,
    required String requestRegion,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('justifications')
        .where('requestId', isEqualTo: requestId);

    if (currentUser.isStudent) {
      query = query.where('userId', isEqualTo: currentUser.uid);
    } else if (currentUser.isRegionalCoordinator) {
      query = query.where(
        'region',
        isEqualTo: RegionUtils.normalize(requestRegion),
      );
    }

    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      final justifications = snapshot.docs
          .map((doc) => JustificationModel.fromDocument(doc))
          .toList();
      justifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return justifications;
    });
  }

  Future<void> addExpenseJustification({
    required RequestModel request,
    required UserModel student,
    required PlatformFile file,
    required double amount,
    required String category,
    required DateTime expenseDate,
    String? note,
  }) async {
    if (!student.isStudent || request.userId != student.uid) {
      throw Exception('Seul l\'etudiant concerne peut envoyer un justificatif');
    }
    if (!request.isApprouveConseil) {
      throw Exception(
        'Les justificatifs peuvent etre envoyes apres validation du Conseil',
      );
    }
    if (amount <= 0) {
      throw Exception('Montant invalide');
    }

    final bytes = await _readUploadBytes(file);
    if (bytes.lengthInBytes > maxFileBytes) {
      throw Exception('Fichier trop volumineux, maximum 10 Mo');
    }

    final docRef = _firestore.collection('justifications').doc();
    final safeFileName = _safeFileName(file.name);
    final contentType = _contentTypeFor(safeFileName);
    final storageRef = _storage.ref().child(
      'justifications/${student.uid}/${request.id}/${docRef.id}_$safeFileName',
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
    final normalizedRegion = RegionUtils.normalize(request.region);
    final cleanNote = note?.trim();

    final batch = _firestore.batch();
    batch.set(docRef, {
      'requestId': request.id,
      'userId': student.uid,
      'region': normalizedRegion,
      'amount': amount,
      'category': category,
      'expenseDate': Timestamp.fromDate(expenseDate),
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
    batch.update(_firestore.collection('requests').doc(request.id), {
      'justificationUrl': fileUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> reviewJustification({
    required String justificationId,
    required String status,
    required UserModel reviewer,
    String? rejectionReason,
  }) async {
    final normalizedStatus = JustificationModel.normalizeStatus(status);
    if (!const {
      'approved',
      'rejected',
      'needs_correction',
    }.contains(normalizedStatus)) {
      throw Exception('Statut de validation invalide');
    }

    await _firestore.collection('justifications').doc(justificationId).update({
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
    final fallback = fileName.trim().isEmpty ? 'justificatif.pdf' : fileName;
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
