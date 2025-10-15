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
  bool _isRefreshing = false; // Flag pour éviter loop refresh
  bool _isLoadingUserModel =
      false; // Nouveau: Flag pour indiquer le chargement async

  // Getters
  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoadingUserModel => _isLoadingUserModel;

  // =====================================================
  // STREAM DU USERMODEL (temps réel) - Amélioré pour debug et gestion d'erreurs
  // =====================================================
  Stream<UserModel?> get userModelStream {
    // Si pas d'utilisateur connecté, retourner null
    if (_user == null) {
      debugPrint('🔍 [Stream] Pas d\'user connecté - Stream null');
      return Stream.value(null);
    }

    debugPrint('🔍 [Stream] Démarrage stream pour UID: ${_user!.uid}');

    return _firestore
        .collection('users')
        .doc(_user!.uid)
        .snapshots()
        .map((doc) {
          // Si le document n'existe pas
          if (!doc.exists) {
            debugPrint(
              '⚠️ [Stream] Document utilisateur non trouvé pour ${_user!.uid}',
            );
            return null;
          }

          try {
            // Parser le UserModel
            final parsedModel = UserModel.fromDocument(doc);
            debugPrint(
              '🔍 [Stream] UserModel stream mis à jour: rôle=${parsedModel.role}, status=${parsedModel.status}',
            );

            // Mettre à jour seulement si différent (évite notify excessif)
            if (_userModel?.uid != parsedModel.uid ||
                _userModel?.role != parsedModel.role) {
              _userModel = parsedModel;
              notifyListeners();
            }

            return _userModel;
          } catch (e) {
            debugPrint('❌ [Stream] Erreur parsing UserModel: $e');
            return null;
          }
        })
        .handleError((error) {
          debugPrint('❌ [Stream] Erreur stream userModel: $error');
          // Ne pas crasher le stream - retourner null
          return null;
        });
  }

  // =====================================================
  // CONSTRUCTEUR - Amélioré avec écoute du stream
  // =====================================================
  AppAuthProvider() {
    // Écouter les changements d'authentification
    _auth.authStateChanges().listen((User? user) {
      debugPrint(
        '🔍 [Constructor] Changement auth: user=${user?.uid ?? "null"}',
      );
      _user = user;
      if (user == null) {
        _userModel = null;
        _isLoadingUserModel = false;
      } else {
        // Démarrer le chargement du userModel async
        _loadUserModel();
      }
      notifyListeners();
    });
  }

  // Méthode helper pour charger userModel (appelée après auth change)
  Future<void> _loadUserModel() async {
    if (_user == null || _isLoadingUserModel) return;
    _isLoadingUserModel = true;
    notifyListeners(); // Indiquer chargement en cours

    try {
      debugPrint('🔍 [_loadUserModel] Chargement pour UID: ${_user!.uid}');
      final doc = await _firestore.collection('users').doc(_user!.uid).get();

      if (!doc.exists) {
        debugPrint(
          '⚠️ [_loadUserModel] Doc non trouvé - Créer un user par défaut ?',
        );
        _userModel = null;
      } else {
        _userModel = UserModel.fromDocument(doc);
        debugPrint(
          '🔍 [_loadUserModel] Chargé: rôle=${_userModel!.role}, status=${_userModel!.status}',
        );
      }
    } catch (e) {
      debugPrint('❌ [_loadUserModel] Erreur: $e');
      _userModel = null;
    } finally {
      _isLoadingUserModel = false;
      notifyListeners();
    }
  }

  // =====================================================
  // CONNEXION - Améliorée avec chargement async et debug
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
      debugPrint('🔍 [signIn] Auth OK - UID: ${_user!.uid}');

      if (_user != null) {
        // Étape 2: Charger userModel async (au lieu de get() direct)
        await _loadUserModel();

        if (_userModel == null) {
          await signOut();
          throw Exception('Utilisateur non trouvé dans la base de données');
        }

        // Étape 3: Vérifier le statut
        if (_userModel!.status != 'approved') {
          await signOut();
          throw Exception(
            'Compte ${_userModel!.status == 'pending' ? 'en attente d\'approbation' : 'rejeté'}',
          );
        }

        // Étape 4: Rafraîchir le token pour propager les custom claims
        await _user!.getIdToken(true);

        debugPrint(
          '✅ Connexion réussie pour: ${_userModel!.email} - Rôle: ${_userModel!.role}',
        );
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

      // Nettoyer en cas d'erreur
      await signOut();
      throw Exception(message);
    } catch (e) {
      debugPrint('❌ Erreur connexion: $e');
      await signOut(); // Nettoyer
      throw Exception('Erreur de connexion: $e');
    }
  }

  // =====================================================
  // INSCRIPTION - Améliorée avec debug
  // =====================================================
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String region,
    required String role,
  }) async {
    try {
      debugPrint('📝 Tentative d\'inscription pour: $email - Rôle: $role');

      // Étape 1: Créer l'utilisateur dans Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = userCredential.user;
      debugPrint('🔍 [signUp] Auth créée - UID: ${_user!.uid}');

      if (_user != null) {
        // Étape 2: Créer le document Firestore
        final userModel = UserModel(
          uid: _user!.uid,
          email: email,
          fullName: fullName,
          region: region,
          role: role,
          status: 'pending', // En attente par défaut (sauf admin)
          createdAt: DateTime.now(),
          photoUrl: null,
        );

        // Sauvegarder dans Firestore
        await _firestore
            .collection('users')
            .doc(_user!.uid)
            .set(userModel.toMap());

        _userModel = userModel;
        debugPrint('✅ [signUp] Inscription réussie - Status: pending');

        notifyListeners();
      }
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
        debugPrint('🧹 [signUp] User supprimé suite à échec');
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
  // DÉCONNEXION - Sans changement
  // =====================================================
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _user = null;
      _userModel = null;
      _isLoadingUserModel = false;
      debugPrint('✅ Déconnexion réussie');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur déconnexion: $e');
      throw Exception('Erreur de déconnexion: $e');
    }
  }

  // =====================================================
  // RAFRAÎCHIR LE USERMODEL - Amélioré pour éviter loops
  // =====================================================
  Future<UserModel?> refreshUserModel() async {
    if (_user == null) {
      debugPrint('⚠️ [refresh] Pas d\'user pour rafraîchir');
      return null;
    }

    if (_isRefreshing) {
      debugPrint('⏳ [refresh] Déjà en cours - Skip');
      return _userModel;
    }
    _isRefreshing = true;

    try {
      debugPrint('🔄 [refresh] Rafraîchissement pour UID: ${_user!.uid}');
      final doc = await _firestore.collection('users').doc(_user!.uid).get();

      if (doc.exists) {
        final newModel = UserModel.fromDocument(doc);
        if (_userModel?.uid != newModel.uid ||
            _userModel?.role != newModel.role ||
            _userModel?.status != newModel.status) {
          _userModel = newModel;
          debugPrint(
            '🔍 [refresh] Changement détecté: nouveau rôle=${_userModel!.role}',
          );
          notifyListeners();
        } else {
          debugPrint('ℹ️ [refresh] Pas de changement');
        }
        return _userModel;
      } else {
        debugPrint('⚠️ [refresh] Doc non trouvé');
      }
    } catch (e) {
      debugPrint('❌ [refresh] Erreur: $e');
    } finally {
      _isRefreshing = false;
    }
    return _userModel;
  }

  // Méthode publique pour forcer le re-load (utile pour debug post-login)
  Future<void> forceReloadUserModel() async {
    await _loadUserModel();
  }
}
