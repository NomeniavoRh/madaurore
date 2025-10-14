import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AppAuthProvider with ChangeNotifier {
  // Instances Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // État de l'utilisateur
  User? _user;
  UserModel? _userModel;
  
  // Getters
  User? get user => _user;
  UserModel? get userModel => _userModel;
  
  // =====================================================
  // STREAM DU USERMODEL (temps réel)
  // =====================================================
  Stream<UserModel?> get userModelStream {
    // Si pas d'utilisateur connecté, retourner null
    if (_user == null) return Stream.value(null);
    
    return _firestore
        .collection('users')
        .doc(_user!.uid)
        .snapshots()
        .map((doc) {
          // Si le document n'existe pas
          if (!doc.exists) {
            debugPrint('⚠️ Document utilisateur non trouvé pour ${_user!.uid}');
            return null;
          }
          
          try {
            // Parser le UserModel
            _userModel = UserModel.fromDocument(doc);
            
            // Notifier les listeners
            notifyListeners();
            
            return _userModel;
          } catch (e) {
            debugPrint('❌ Erreur parsing UserModel: $e');
            return null;
          }
        })
        .handleError((error) {
          debugPrint('❌ Erreur stream userModel: $error');
          return null;
        });
  }
  
  // =====================================================
  // CONSTRUCTEUR
  // =====================================================
  AppAuthProvider() {
    // Écouter les changements d'authentification
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user == null) {
        _userModel = null;
      }
      notifyListeners();
    });
  }
  
  // =====================================================
  // CONNEXION
  // =====================================================
  Future<void> signIn(String email, String password) async {
    try {
      debugPrint('🔐 Tentative de connexion pour: $email');
      
      // Étape 1: Authentifier avec Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _user = userCredential.user;
      
      if (_user != null) {
        // Étape 2: Récupérer les données utilisateur depuis Firestore
        final doc = await _firestore.collection('users').doc(_user!.uid).get();
        
        if (!doc.exists) {
          await signOut();
          throw Exception('Utilisateur non trouvé dans la base de données');
        }
        
        // Étape 3: Parser le UserModel
        _userModel = UserModel.fromDocument(doc);
        
        // Étape 4: Vérifier le statut
        if (_userModel!.status != 'approved') {
          await signOut();
          throw Exception('Compte ${_userModel!.status == 'pending' ? 'en attente d\'approbation' : 'rejeté'}');
        }
        
        debugPrint('✅ Connexion réussie pour: ${_userModel!.email}');
      }
      
      notifyListeners();
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Erreur FirebaseAuth: ${e.code}');
      
      // Traduire les erreurs Firebase en français
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Aucun utilisateur trouvé avec cet email';
          break;
        case 'wrong-password':
          message = 'Mot de passe incorrect';
          break;
        case 'invalid-email':
          message = 'Email invalide';
          break;
        case 'user-disabled':
          message = 'Ce compte a été désactivé';
          break;
        case 'too-many-requests':
          message = 'Trop de tentatives. Réessayez plus tard';
          break;
        case 'invalid-credential':
          message = 'Email ou mot de passe incorrect';
          break;
        default:
          message = 'Erreur de connexion: ${e.message}';
      }
      
      throw Exception(message);
      
    } catch (e) {
      debugPrint('❌ Erreur connexion: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }
  
  // =====================================================
  // INSCRIPTION
  // =====================================================
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String region,
    required String role,
  }) async {
    try {
      debugPrint('📝 Tentative d\'inscription pour: $email');
      
      // Étape 1: Créer l'utilisateur dans Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _user = userCredential.user;
      
      if (_user != null) {
        // Étape 2: Créer le document Firestore
        // IMPORTANT: Utiliser toMap() qui convertit Timestamp correctement
        final userModel = UserModel(
          uid: _user!.uid,
          email: email,
          fullName: fullName,
          region: region,
          role: role,
          status: 'pending', // En attente par défaut
          createdAt: DateTime.now(),
          photoUrl: null,
        );
        
        // Sauvegarder dans Firestore (pas de cache Hive)
        await _firestore
            .collection('users')
            .doc(_user!.uid)
            .set(userModel.toMap());
        
        _userModel = userModel;
        
        debugPrint('✅ Inscription réussie pour: $email');
      }
      
      notifyListeners();
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Erreur FirebaseAuth inscription: ${e.code}');
      
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Cet email est déjà utilisé';
          break;
        case 'weak-password':
          message = 'Le mot de passe doit contenir au moins 6 caractères';
          break;
        case 'invalid-email':
          message = 'Email invalide';
          break;
        default:
          message = 'Erreur d\'inscription: ${e.message}';
      }
      
      // Nettoyer si échec
      if (_user != null) {
        await _user!.delete();
      }
      
      throw Exception(message);
      
    } catch (e) {
      debugPrint('❌ Erreur inscription: $e');
      
      // Nettoyer si échec
      if (_user != null) {
        await _user!.delete();
      }
      
      throw Exception('Erreur d\'inscription: $e');
    }
  }
  
  // =====================================================
  // DÉCONNEXION
  // =====================================================
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _user = null;
      _userModel = null;
      debugPrint('✅ Déconnexion réussie');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur déconnexion: $e');
      throw Exception('Erreur de déconnexion: $e');
    }
  }
  
  // =====================================================
  // RAFRAÎCHIR LE USERMODEL
  // =====================================================
  Future<void> refreshUserModel() async {
    if (_user == null) return;
    
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      
      if (doc.exists) {
        _userModel = UserModel.fromDocument(doc);
        notifyListeners();
        debugPrint('✅ UserModel rafraîchi');
      }
    } catch (e) {
      debugPrint('❌ Erreur rafraîchissement: $e');
    }
  }
}