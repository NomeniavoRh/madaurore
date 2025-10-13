import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AppAuthProvider extends ChangeNotifier {
  User? _user;
  UserModel? _userModel;
  Stream<UserModel?>? _userModelStream;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  Stream<UserModel?> get userModelStream =>
      _userModelStream ??= _getUserModelStream();

  AppAuthProvider() {
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) fetchUserModel();
  }

  Future<void> signIn(String email, String password) async {
    try {
      _user = (await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      )).user;
      await fetchUserModel();
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur signIn: $e');
      rethrow;
    }
  }

  Future<UserCredential> signUp(
    String email,
    String password,
    String fullName,
    String region,
    String role,
  ) async {
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final status = (role == 'admin')
          ? 'approved'
          : 'pending'; // ← Fix : Auto-approved pour admin
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'email': email,
            'fullName': fullName,
            'region': region,
            'role': role,
            'status': status, // ← Utilise variable pour auto-approved
            'createdAt': Timestamp.now(),
          });
      _user = userCredential.user;
      await fetchUserModel();
      notifyListeners();
      return userCredential;
    } catch (e) {
      debugPrint('Erreur signUp: $e');
      rethrow;
    }
  }

  Future<void> fetchUserModel() async {
    if (_user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      if (doc.exists) {
        _userModel = UserModel.fromDocument(doc);
        notifyListeners();
      }
    }
  }

  Stream<UserModel?> _getUserModelStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_user?.uid ?? '')
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return UserModel.fromDocument(doc);
        });
  }

  void signOut() {
    FirebaseAuth.instance.signOut();
    _user = null;
    _userModel = null;
    notifyListeners();
  }
}
