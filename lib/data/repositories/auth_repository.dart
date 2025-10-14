import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Stream de l'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Connexion
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Inscription
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String fullName,
    required String region,
    required String role,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _createUserProfile(
        userCredential: userCredential,
        fullName: fullName,
        region: region,
        role: role,
      );

      return userCredential;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Création du profil utilisateur
  Future<void> _createUserProfile({
    required UserCredential userCredential,
    required String fullName,
    required String region,
    required String role,
  }) async {
    final status = (role == 'admin') ? 'approved' : 'pending';

    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'uid': userCredential.user!.uid,
      'email': userCredential.user!.email,
      'fullName': fullName,
      'region': region,
      'role': role,
      'status': status,
      'photoUrl': null,
      'createdAt': Timestamp.now(),
    });
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Gestion des erreurs
  String _handleAuthError(dynamic error) {
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
}
