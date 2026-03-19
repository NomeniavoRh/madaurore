import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';

class AppAuthProvider with ChangeNotifier {
  // Instances Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // État de l'utilisateur
  User? _user;
  UserModel? _userModel;
  bool _isRefreshing = false;
  bool _isLoadingUserModel = false;

  // 🔥 NOUVEAU: Tracker les appels en cours pour éviter les doublons
  Future<void>? _loadingFuture;

  // Getters
  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoadingUserModel => _isLoadingUserModel;

  Stream<UserModel?> get userModelStream {
    if (_user == null) {
      debugPrint(' [Stream] Pas d\'user connecté - Stream null');
      return Stream.value(null);
    }

    debugPrint('[Stream] Démarrage stream pour UID: ${_user!.uid}');

    return _firestore
        .collection('users')
        .doc(_user!.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) {
            debugPrint(
              ' [Stream] Document utilisateur non trouvé pour ${_user!.uid}',
            );
            return null;
          }

          try {
            final parsedModel = UserModel.fromDocument(doc);
            debugPrint(
              '[Stream] UserModel stream mis à jour: rôle=${parsedModel.role}, status=${parsedModel.status}',
            );

            if (_userModel?.uid != parsedModel.uid ||
                _userModel?.role != parsedModel.role) {
              _userModel = parsedModel;
              notifyListeners();
            }

            return _userModel;
          } catch (e) {
            debugPrint('[Stream] Erreur parsing UserModel: $e');
            return null;
          }
        })
        .handleError((error) {
          debugPrint(' [Stream] Erreur stream userModel: $error');
          return null;
        });
  }

  AppAuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      debugPrint('[Constructor] Changement auth: user=${user?.uid ?? "null"}');
      _user = user;
      if (user == null) {
        _userModel = null;
        _isLoadingUserModel = false;
        _loadingFuture = null;
      } else {
        // 🔥 NE PAS attendre ici - laisser signIn() s'en charger
        _loadUserModel();
      }
      notifyListeners();
    });
  }

  /// ✅ CORRIGÉ: Évite les appels multiples simultanées
  Future<void> _loadUserModel() async {
    // Si déjà en cours, attendre le résultat existant
    if (_loadingFuture != null) {
      debugPrint(
        '[_loadUserModel] ⏳ Chargement déjà en cours - Attendre le résultat',
      );
      await _loadingFuture;
      return;
    }

    // Vérification: user doit exister
    if (_user == null) {
      debugPrint('[_loadUserModel] Skip: user null');
      return;
    }

    // Créer la Future une seule fois
    _loadingFuture = _performLoadUserModel();

    try {
      await _loadingFuture;
    } finally {
      _loadingFuture = null;
    }
  }

  /// La logique réelle du chargement
  Future<void> _performLoadUserModel() async {
    _isLoadingUserModel = true;
    notifyListeners();

    try {
      final currentUid = _user?.uid;

      if (currentUid == null) {
        debugPrint('[_performLoadUserModel] User null pendant le chargement');
        _userModel = null;
        return;
      }

      debugPrint('[_performLoadUserModel] Chargement pour UID: $currentUid');

      DocumentSnapshot doc;
      try {
        doc = await _firestore.collection('users').doc(currentUid).get();
      } on FirebaseException catch (e) {
        // Gestion spéciale pour les erreurs web
        if (e.code == 'permission-denied' && kIsWeb) {
          debugPrint(
            '[_performLoadUserModel] Permission-denied détecté sur web → retry après 1.5s',
          );
          await Future.delayed(const Duration(milliseconds: 1500));
          doc = await _firestore.collection('users').doc(currentUid).get();
        } else {
          rethrow;
        }
      }

      // Vérification: l'utilisateur n'est pas déconnecté entre temps
      if (_user == null || _user!.uid != currentUid) {
        debugPrint(
          '[_performLoadUserModel] ⚠️ User état changé pendant le chargement',
        );
        _userModel = null;
        return;
      }

      // Vérification: le document Firestore existe
      if (!doc.exists || doc.data() == null) {
        debugPrint(
          '[_performLoadUserModel] ❌ Document Firestore introuvable pour $currentUid',
        );
        _userModel = null;
        throw Exception('Utilisateur non trouvé dans la base de données');
      }

      // Parse le document
      _userModel = UserModel.fromDocument(doc);

      debugPrint(
        '✅ [_performLoadUserModel] Chargé avec succès: '
        'email=${_userModel?.email}, '
        'rôle=${_userModel?.role}, '
        'status=${_userModel?.status}',
      );
    } catch (e) {
      debugPrint('❌ [_performLoadUserModel] Erreur: $e');
      _userModel = null;
      rethrow;
    } finally {
      _isLoadingUserModel = false;
      notifyListeners();
    }
  }

  /// ✅ Connexion utilisateur
  Future<void> signIn(String email, String password) async {
    try {
      debugPrint('🔍 [signIn] Tentative de connexion pour: $email');

      // 1. Authentification Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      _user = userCredential.user;
      debugPrint('[signIn] ✅ Auth OK - UID: ${_user!.uid}');

      if (_user != null) {
        // 2. Refresh du token
        await _user!.getIdToken(true);
        debugPrint('[signIn] Token refresh forcé');

        // 3. Délai critique pour Web (propagation du token Firestore)
        if (kIsWeb) {
          debugPrint(
            '[signIn] Web detected → attente propagation token (1.5s)...',
          );
          await Future.delayed(const Duration(milliseconds: 1500));
        }

        // 4. Charger le profil utilisateur depuis Firestore
        await _loadUserModel();
        debugPrint('[signIn] ✅ _loadUserModel terminé');

        // 5. Vérifications de sécurité
        if (_userModel == null) {
          debugPrint('[signIn] ❌ UserModel null après chargement');
          await signOut();
          throw Exception('Utilisateur non trouvé dans la base de données');
        }

        // 6. Vérifier le statut du compte
        if (_userModel!.status != 'approved') {
          debugPrint('[signIn] ⚠️ Compte status=${_userModel!.status}');
          await signOut();

          if (_userModel!.status == 'pending') {
            throw Exception(
              'Compte en attente d\'approbation par un administrateur',
            );
          } else if (_userModel!.status == 'rejected') {
            throw Exception(
              'Votre compte a été rejeté. Contactez un administrateur',
            );
          } else {
            throw Exception(
              'Votre compte n\'est pas disponible (status: ${_userModel!.status})',
            );
          }
        }

        debugPrint(
          '✅ [signIn] Connexion réussie pour: $email - '
          'Rôle: ${_userModel!.role}, Région: ${_userModel!.region}',
        );
      }

      notifyListeners();
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [signIn] FirebaseAuthException: ${e.code}');

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
        case 'operation-not-allowed':
          message = 'La connexion par email/mot de passe n\'est pas activée';
          break;
        default:
          message = 'Erreur de connexion: ${e.message}';
      }

      await signOut();
      throw Exception(message);
    } catch (e) {
      debugPrint('❌ [signIn] Erreur inattendue: $e');
      await signOut();
      rethrow;
    }
  }

  /// ✅ Inscription utilisateur
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String region,
    required String role,
  }) async {
    try {
      debugPrint(
        '📝 [signUp] Tentative d\'inscription: email=$email, role=$role, region=$region',
      );

      // 1. Créer le compte Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      _user = userCredential.user;
      debugPrint('[signUp] ✅ Compte Auth créé - UID: ${_user!.uid}');

      if (_user != null) {
        // 2. Refresh du token
        await _user!.getIdToken(true);
        debugPrint('[signUp] Token refresh forcé après inscription');

        // 3. Créer le profil utilisateur dans Firestore
        final userModel = UserModel(
          uid: _user!.uid,
          email: email.trim(),
          fullName: fullName.trim(),
          region: region,
          role: role,
          status: 'pending', // Attendre approbation admin
          createdAt: DateTime.now(),
          photoUrl: null,
          memberStatus: 'new_member',
        );

        await _firestore
            .collection('users')
            .doc(_user!.uid)
            .set(userModel.toMap());

        _userModel = userModel;

        debugPrint(
          '✅ [signUp] Inscription réussie - '
          'UID: ${_user!.uid}, Email: $email, Status: pending',
        );

        notifyListeners();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [signUp] FirebaseAuthException: ${e.code}');

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
        case 'operation-not-allowed':
          message = 'L\'inscription par email/mot de passe n\'est pas activée';
          break;
        default:
          message = 'Erreur d\'inscription: ${e.message}';
      }

      // Cleanup: supprimer le compte Auth créé en cas d'erreur Firestore
      if (_user != null) {
        try {
          await _user!.delete();
          debugPrint('🧹 [signUp] Compte Auth supprimé suite à erreur');
        } catch (deleteError) {
          debugPrint(
            '⚠️ [signUp] Erreur lors de la suppression du compte: $deleteError',
          );
        }
      }

      throw Exception(message);
    } catch (e) {
      debugPrint('❌ [signUp] Erreur inattendue: $e');

      // Cleanup final
      if (_user != null) {
        try {
          await _user!.delete();
          debugPrint('🧹 [signUp] Compte Auth supprimé (cleanup)');
        } catch (deleteError) {
          debugPrint('⚠️ [signUp] Erreur cleanup: $deleteError');
        }
      }

      throw Exception('Erreur d\'inscription: $e');
    }
  }

  /// ✅ Déconnexion utilisateur
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _user = null;
      _userModel = null;
      _isLoadingUserModel = false;
      _loadingFuture = null;
      debugPrint('✅ Déconnexion réussie');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur déconnexion: $e');
      throw Exception('Erreur de déconnexion: $e');
    }
  }

  /// 🔄 Rafraîchir le UserModel depuis Firestore
  Future<UserModel?> refreshUserModel() async {
    if (_user == null) {
      debugPrint('[refreshUserModel] Pas d\'user connecté');
      return null;
    }

    if (_isRefreshing) {
      debugPrint('⏳ [refreshUserModel] Déjà en cours - Skip');
      return _userModel;
    }

    _isRefreshing = true;

    try {
      debugPrint(
        '🔄 [refreshUserModel] Rafraîchissement pour UID: ${_user!.uid}',
      );

      final doc = await _firestore.collection('users').doc(_user!.uid).get();

      if (doc.exists && doc.data() != null) {
        final newModel = UserModel.fromDocument(doc);

        // Vérifier s'il y a eu des changements
        if (_userModel?.uid != newModel.uid ||
            _userModel?.role != newModel.role ||
            _userModel?.status != newModel.status) {
          _userModel = newModel;
          debugPrint(
            '🔍 [refreshUserModel] Changement détecté: '
            'rôle=${_userModel?.role}, status=${_userModel?.status}',
          );
          notifyListeners();
        } else {
          debugPrint('ℹ️ [refreshUserModel] Pas de changement');
        }

        return _userModel;
      } else {
        debugPrint('⚠️ [refreshUserModel] Document non trouvé');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [refreshUserModel] Erreur: $e');
      return _userModel;
    } finally {
      _isRefreshing = false;
    }
  }

  /// 🔄 Force la réinitialisation du UserModel
  Future<void> forceReloadUserModel() async {
    debugPrint('[forceReloadUserModel] Force reload en cours...');
    _isLoadingUserModel = false;
    _loadingFuture = null;
    await _loadUserModel();
  }
}
    