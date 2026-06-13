// lib/services/firebase_setup.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 🔧 Script d'initialisation Firebase pour Madaction
/// À exécuter UNE SEULE FOIS pour créer les données initiales
class FirebaseSetup {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Lance l'initialisation complète
  static Future<void> initialize() async {
    debugPrint('🚀 === DÉBUT INITIALISATION FIREBASE ===');

    try {
      await _createRegions();
      await _createAdminAccount();
      debugPrint('✅ === INITIALISATION TERMINÉE ===');
      debugPrint('');
      debugPrint('📧 Compte Admin créé');
      debugPrint(
        '⚠️  LES IDENTIFIANTS SONT AFFICHÉS EN CONSOLE - NE JAMAIS PUSHER CE FICHIER',
      );
    } catch (e) {
      debugPrint('❌ Erreur d\'initialisation: $e');
      rethrow;
    }
  }

  /// Crée les 4 régions de Madagascar
  static Future<void> _createRegions() async {
    debugPrint('📍 Création des régions...');

    final regions = ['Antananarivo', 'Antsirabe', 'Fianarantsoa', 'Toliara'];

    for (final region in regions) {
      try {
        // Vérifier si la région existe déjà
        final doc = await _firestore.collection('regions').doc(region).get();

        if (!doc.exists) {
          await _firestore.collection('regions').doc(region).set({
            'name': region,
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint('  ✓ $region créée');
        } else {
          debugPrint('  ⊙ $region existe déjà');
        }
      } catch (e) {
        debugPrint('  ✗ Erreur $region: $e');
      }
    }
  }

  /// Crée le compte administrateur principal
  static Future<void> _createAdminAccount() async {
    debugPrint('👤 Création du compte administrateur...');

    const adminEmail = 'admin@madaction.mg';
    const adminPassword = 'Admin@2024Secure!';

    try {
      // Vérifier si le compte existe déjà
      final existingUsers = await _firestore
          .collection('users')
          .where('email', isEqualTo: adminEmail)
          .limit(1)
          .get();

      if (existingUsers.docs.isEmpty) {
        // Créer le compte dans Firebase Authentication
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );

        final uid = userCredential.user!.uid;

        // Créer le profil dans Firestore
        await _firestore.collection('users').doc(uid).set({
          'uid': uid,
          'email': adminEmail,
          'fullName': 'Administrateur Principal',
          'region': 'Antananarivo',
          'role': 'admin',
          'status': 'approved', // Admin auto-approuvé
          'photoUrl': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('  ✓ Compte admin créé avec succès');
        debugPrint('  📋 UID: $uid');
      } else {
        debugPrint('  ⊙ Compte admin existe déjà');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        debugPrint('  ⊙ Email déjà utilisé (compte existe)');
      } else {
        debugPrint('  ✗ Erreur Firebase Auth: ${e.message}');
        rethrow;
      }
    } catch (e) {
      debugPrint('  ✗ Erreur inattendue: $e');
      rethrow;
    }
  }

  /// 🧪 Crée des comptes de test (optionnel - pour développement)
  static Future<void> createTestAccounts() async {
    debugPrint('');
    debugPrint('🧪 === CRÉATION DE COMPTES DE TEST ===');

    // Compte Coordinateur Test
    await _createTestAccount(
      email: 'coordo.test@madaction.mg',
      password: 'Test@2024',
      fullName: 'Coordinateur Test',
      region: 'Fianarantsoa',
      role: 'regional_coordinator',
      status: 'approved', // Déjà approuvé pour les tests
    );

    // Compte Étudiant Test (en attente)
    await _createTestAccount(
      email: 'etudiant.test@madaction.mg',
      password: 'Test@2024',
      fullName: 'Étudiant Test',
      region: 'Antananarivo',
      role: 'student',
      status: 'pending', // En attente d'approbation
    );

    debugPrint('✅ === COMPTES DE TEST CRÉÉS ===');
  }

  /// Fonction helper pour créer un compte de test
  static Future<void> _createTestAccount({
    required String email,
    required String password,
    required String fullName,
    required String region,
    required String role,
    required String status,
  }) async {
    try {
      // Vérifier si le compte existe
      final existingUsers = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingUsers.docs.isEmpty) {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final uid = userCredential.user!.uid;

        await _firestore.collection('users').doc(uid).set({
          'uid': uid,
          'email': email,
          'fullName': fullName,
          'region': region,
          'role': role,
          'status': status,
          'photoUrl': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('  ✓ $email créé (role: $role, status: $status)');
      } else {
        debugPrint('  ⊙ $email existe déjà');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        debugPrint('  ⊙ $email existe déjà');
      } else {
        debugPrint('  ✗ Erreur pour $email: ${e.message}');
      }
    }
  }

  /// 🗑️ Nettoie les comptes de test (UTILISER AVEC PRÉCAUTION!)
  static Future<void> cleanupTestAccounts() async {
    debugPrint('');
    debugPrint('🧹 === NETTOYAGE DES COMPTES DE TEST ===');
    debugPrint('  Cette action supprimera les comptes de test');

    final testEmails = [
      'coordo.test@madaction.mg',
      'etudiant.test@madaction.mg',
    ];

    for (final email in testEmails) {
      try {
        final users = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        for (final doc in users.docs) {
          await doc.reference.delete();
          debugPrint('  $email supprimé de Firestore');
        }
      } catch (e) {
        debugPrint('   Erreur suppression $email: $e');
      }
    }

    debugPrint(' Nettoyage terminé');
    debugPrint('  Note: Les comptes Auth doivent être supprimés manuellement');
  }
}
