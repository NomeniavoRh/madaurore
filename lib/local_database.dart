import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalDatabase {
  static const String _boxName = 'madactionData';
  static late Box _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  static Future<void> cacheUser(String uid, Map<String, dynamic> data) async {
    await _box.put('user_$uid', data);
  }

  static Map<String, dynamic>? getCachedUser(String uid) {
    return _box.get('user_$uid');
  }

  static Future<void> cacheRequest(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    await _box.put('request_$requestId', data);
  }

  static Map<String, dynamic>? getCachedRequest(String requestId) {
    return _box.get('request_$requestId');
  }

  static Future<void> cacheJustificatif(
    String justificatifId,
    Map<String, dynamic> data,
  ) async {
    await _box.put('justificatif_$justificatifId', data);
  }

  static Map<String, dynamic>? getCachedJustificatif(String justificatifId) {
    return _box.get('justificatif_$justificatifId');
  }

  // Synchronise le cache avec Firestore (appelé après connexion ou mise à jour)
  static Future<void> syncCacheWithFirestore(String uid, String role) async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection('requests')
        .where('userId', isEqualTo: uid)
        .get();
    for (var doc in snapshot.docs) {
      await cacheRequest(doc.id, doc.data());
    }
  }
}
