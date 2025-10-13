import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadJustification(
    String filePath,
    String userId,
    String requestId,
  ) async {
    final file = File(filePath);
    final bytes = await file.length();
    const maxBytes = 10 * 1024 * 1024;
    if (bytes > maxBytes) {
      throw Exception('File too large. Max 10MB allowed.');
    }

    final fileName = p.basename(filePath);
    final ref = _storage.ref().child('justifications/$userId/$requestId/$fileName');
    final task = await ref.putFile(file);
    final url = await task.ref.getDownloadURL();
    return url;
  }
}
