import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AppAuthProvider extends ChangeNotifier {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Private state variables
  User? _user;
  UserModel? _userModel;
  Stream<UserModel?>? _userModelStream;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get user => _user;
  UserModel? get userModel => _userModel;
  Stream<UserModel?> get userModelStream =>
      _userModelStream ??= _getUserModelStream();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AppAuthProvider() {
    _user = _auth.currentUser;
    if (_user != null) fetchUserModel();
  }

  Stream<UserModel?> _getUserModelStream() {
    return _firestore.collection('users').doc(_user?.uid ?? '').snapshots().map(
      (doc) {
        if (!doc.exists) return null;
        return UserModel.fromDocument(doc);
      },
    );
  }

  Future<void> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = credential.user;
      await fetchUserModel();
    } catch (e) {
      _errorMessage = _getAuthErrorMessage(e);
      debugPrint('Erreur signIn: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String fullName,
    required String region,
    required String role,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'fullName': fullName,
        'region': region,
        'role': role,
        'status': role == 'admin' ? 'approved' : 'pending',
        'photoUrl': null,
        'createdAt': Timestamp.now(),
      });

      _user = userCredential.user;
      await fetchUserModel();
      return userCredential;
    } catch (e) {
      _errorMessage = _getAuthErrorMessage(e);
      debugPrint('Erreur signUp: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserModel() async {
    try {
      if (_user != null) {
        final doc = await _firestore.collection('users').doc(_user!.uid).get();

        if (doc.exists) {
          _userModel = UserModel.fromDocument(doc);
          _errorMessage = null;
        } else {
          _errorMessage = 'Profil utilisateur non trouvé';
        }
      }
    } catch (e) {
      _errorMessage = 'Erreur de chargement: ${e.toString()}';
      debugPrint('Erreur fetchUserModel: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.signOut();
      _user = null;
      _userModel = null;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Erreur de déconnexion: ${e.toString()}';
      debugPrint('Erreur signOut: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _getAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'Aucun utilisateur trouvé avec cet email';
        case 'wrong-password':
          return 'Mot de passe incorrect';
        case 'email-already-in-use':
          return 'Cet email est déjà utilisé';
        case 'weak-password':
          return 'Le mot de passe est trop faible';
        case 'invalid-email':
          return 'Email invalide';
        default:
          return 'Erreur d\'authentification: ${error.message}';
      }
    }
    return 'Une erreur inattendue s\'est produite';
  }

  // Ajout d'une méthode pour rafraîchir les données utilisateur
  Future<void> refreshUser() async {
    if (_user != null) {
      await fetchUserModel();
    }
  }
}
