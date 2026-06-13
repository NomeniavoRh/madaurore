# 📱 Madaction - Plateforme de Gestion de Parrainage Étudiant

> Application mobile, desktop et web pour la gestion intelligente des demandes de parrainage étudiant

[![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-blue.svg?style=flat&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.9.2+-0175C2.svg?style=flat&logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28.svg?style=flat&logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat)](LICENSE)

## 📋 Vue d'ensemble

**Madaction** est une plateforme complète dédiée à la gestion centralisée des demandes de parrainage étudiant. L'application offre une expérience utilisateur intuitive et différenciée selon le profil, tout en garantissant la sécurité des données et des accès.

### 🎯 Cas d'usage
- **Étudiants** : Créer et suivre les demandes de parrainage, gérer la bio et les justificatifs
- **Coordinateurs régionaux** : Qualifier les demandes de sa région
- **Administrateurs** : Superviser l'ensemble de la plateforme
- **Conseil Administratif** : Consulter et finaliser les demandes globales

---

## ✨ Fonctionnalités principales

### 🔐 Authentification & Sécurité
- Authentification multi-profil via Firebase Auth (email/mot de passe)
- Gestion granulaire des rôles et permissions
- Règles de sécurité Firestore avancées
- Sessions utilisateur sécurisées

### 📊 Tableaux de bord personnalisés
- Tableau de bord **Étudiant** : Vue des demandes et suivi du statut
- Tableau de bord **Coordinateur régional** : Qualification des demandes par région
- Tableau de bord **Administrateur** : Vue globale et gestion complète
- Tableau de bord **Conseil Administratif** : Finalisation des demandes

### 📝 Gestion des demandes
- Création et édition de demandes de parrainage
- Classification par type de membre (`nouveau_membre`, `ancien_membre`)
- Historique des mises à jour et validations
- Statuts progressifs : `pending` → `approved`/`rejected`

### 📄 Documents & exports
- Upload de justificatifs PDF sécurisé
- Export PDF de rapports et récapitulatifs
- Gestion centralisée des fichiers via Firebase Storage

### 👤 Gestion du profil
- Édition du profil utilisateur
- Gestion de la bio étudiant
- Historique des modifications

---

## 🏗️ Architecture technique

### Stack technologique

| Domaine | Technologie |
|---------|------------|
| **Framework** | Flutter 3.9.2+ |
| **Langage** | Dart 3.9.2+ |
| **State Management** | Provider 6.1.2 |
| **Backend** | Firebase (Auth, Firestore, Storage) |
| **PDF/Reporting** | Printing 5.12.0, PDF 3.11.0 |
| **UI** | Google Fonts 6.2.1, Material Design |
| **Utilitaires** | RxDart, path_provider, file_picker, image_picker |

### Structure du projet

```
lib/
├── core/                          # Logique métier & constantes
│   ├── constants/                 # Constantes applicatives
│   └── utils/                     # Fonctions utilitaires
├── data/                          # Couche données
│   ├── models/                    # Modèles Firestore
│   └── repositories/              # Accès aux données & auth
├── presentation/                  # Couche UI
│   ├── screens/
│   │   ├── auth/                  # Écrans authentification
│   │   ├── dashboard/             # Tableaux de bord (multi-rôle)
│   │   ├── members/               # Gestion des membres
│   │   ├── profile/               # Profils utilisateur
│   │   └── students/              # Gestion des étudiants
│   └── widgets/                   # Composants réutilisables
├── services/                      # Services métier
│   ├── firebase/                  # Opérations Firestore, Storage
│   └── auth/                      # Gestion authentification
├── theme/                         # Thème & styles
├── firebase_options.dart          # Configuration Firebase
└── main.dart                      # Point d'entrée
```

### Collections Firestore

| Collection | Description |
|-----------|------------|
| `users` | Comptes utilisateurs et rôles |
| `student_profiles` | Profils détaillés des étudiants |
| `requests` | Demandes de parrainage |
| `validation_requests` | Demandes en attente de validation |
| `justifications` | Justificatifs uploadés |
| `updates` | Historique des mises à jour |
| `regions` | Régions et coordinateurs |

---

## 🚀 Démarrage rapide

### Prérequis

- **Flutter** 3.9.2 ou supérieur ([installer](https://flutter.dev/docs/get-started/install))
- **Dart** 3.9.2 ou supérieur (inclus avec Flutter)
- **Firebase CLI** (optionnel, pour le déploiement)
- Un projet Firebase configuré

### Installation

1. **Cloner le projet**
   ```bash
   git clone <repository-url>
   cd madaurore
   ```

2. **Installer les dépendances**
   ```bash
   flutter pub get
   ```

3. **Configurer Firebase**
   ```bash
   # Placer les fichiers de configuration Firebase
   # - google-services.json (Android)
   # - GoogleService-Info.plist (iOS)
   ```

4. **Lancer l'application**
   ```bash
   # Sur appareil mobile
   flutter run

   # Sur web
   flutter run -d chrome

   # Build de production
   flutter build apk      # Android
   flutter build ios      # iOS
   flutter build web      # Web
   ```

---

## 👥 Système de rôles et accès

### Rôles disponibles

**Student (Étudiant)**
- ✅ Créer et consulter ses demandes
- ✅ Modifier sa bio et son profil
- ✅ Uploader des justificatifs
- ❌ Valider d'autres demandes

**Regional Coordinator (Coordinateur régional)**
- ✅ Consulter les demandes de sa région
- ✅ Qualifier et approuver les demandes
- ✅ Voir les détails des étudiants
- ❌ Accéder à d'autres régions

**Admin (Administrateur)**
- ✅ Accès complet à toutes les données
- ✅ Validation et rejet des demandes
- ✅ Gestion des rôles et utilisateurs
- ✅ Vue globale des statistiques

**Conseil Administratif**
- ✅ Consulter l'ensemble des demandes
- ✅ Finaliser les demandes approuvées
- ✅ Accès en lecture seule

### Règles de sécurité

Les règles de sécurité granulaires sont définies dans [firestore.rules](./firestore.rules) :
- Authentification obligatoire
- Isolation des données par rôle
- Restriction d'accès par région
- Validation des uploads

---

## 🔧 Configuration & Environnement

### Variables d'environnement
```yaml
# firebase_options.dart
Project Firebase: madaction-aeaea
Hosting: build/web
```

### Réglages d'analyse
```yaml
# analysis_options.yaml - Règles Dart Lint
# devtools_options.yaml - Configuration DevTools
```

### Firebase Hosting
L'application web est prête pour le déploiement via :
```bash
firebase deploy --only hosting
```

---

## 📦 Dépendances principales

```yaml
firebase_core: ^4.1.1              # Core Firebase
firebase_auth: ^6.1.0              # Authentification
cloud_firestore: ^6.0.1            # Base de données
firebase_storage: ^13.0.1          # Stockage fichiers
provider: ^6.1.2                   # State management
printing: ^5.12.0                  # Génération PDF
file_picker: ^10.3.3               # Sélection de fichiers
image_picker: ^1.1.2               # Galerie/Caméra
google_fonts: ^6.2.1               # Polices Google
```

Voir [pubspec.yaml](./pubspec.yaml) pour la liste complète.

---

## 💡 Bonnes pratiques

- **State Management** : Provider pour la gestion d'état centralisée
- **Modularité** : Séparation claire entre données, logique et présentation
- **Sécurité** : Authentification et règles Firestore strictes
- **Performance** : Lazy loading et optimisation des requêtes Firestore
- **UX** : Thème cohérent et interactions fluides

---

## 📱 Plateformes supportées

| Plateforme | Support | Status |
|-----------|---------|--------|
| Android | ✅ | Production-ready |
| iOS | ✅ | Production-ready |
| Web | ✅ | Production-ready |
| macOS | ⚠️ | En développement |
| Linux | ⚠️ | En développement |
| Windows | ⚠️ | En développement |

---

## 🐛 Troubleshooting

### Erreurs courantes

**Firebase non initialisé**
```dart
// Vérifier firebase_options.dart et la configuration
```

**Problèmes d'authentification**
- Vérifier les règles Firestore
- Activer Email/Password dans Firebase Console

**Erreurs de build**
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

---

## 🤝 Contribution

Les contributions sont bienvenues ! Merci de :
1. Créer une branche pour votre feature (`git checkout -b feature/AmazingFeature`)
2. Commiter vos changements (`git commit -m 'Add AmazingFeature'`)
3. Pousser vers la branche (`git push origin feature/AmazingFeature`)
4. Ouvrir une Pull Request

---

## 📄 Licence

Ce projet est sous licence MIT - voir [LICENSE](LICENSE) pour plus de détails.

---

## 📞 Support & Contact

- **Documentation** : Voir [wiki](./wiki)
- **Issues** : [GitHub Issues](./issues)
- **Email** : contact@madaction.fr

---

**Dernière mise à jour** : Avril 2026 | **Version** : 1.0.0

Installer les dépendances:

```bash
flutter pub get
```

Lancer sur le web:

```bash
flutter run -d chrome
```

Lancer sur Windows:

```bash
flutter run -d windows
```

Construire le web:

```bash
flutter build web
```

Déployer sur Firebase Hosting:

```bash
firebase deploy
```

## Points importants de l'implémentation

- L'initialisation Firebase est centralisée dans `lib/main.dart`
- Sur le web, Firestore désactive explicitement la persistence pour éviter certains problèmes de synchro
- La navigation dépend du rôle chargé depuis `users/{uid}`
- Les dashboards métier lisent directement Firestore avec `StreamBuilder` et `FutureBuilder`
- Les exports PDF sont générés côté client

## Limites actuelles

- Le `README` d'origine ne décrivait pas le projet réel
- Le dépôt contient encore des changements en cours de stabilisation
- Plusieurs fichiers présentent des problèmes d'encodage de caractères
- La couverture de test est très faible voire absente
- Une partie de la logique métier est encore directement embarquée dans des écrans volumineux

## Optimisation proposée

Optimisation prioritaire recommandée: extraire la logique Firestore et la logique métier des grands écrans vers des services et contrôleurs dédiés.

Pourquoi c'est le meilleur levier maintenant:
- les écrans `dashboard_admin`, `dashboard_coordo` et `dashboard_conseil` sont déjà très gros
- les requêtes Firestore, les calculs métier, l'export PDF et les actions de validation sont mélangés dans l'UI
- cela rend les corrections plus risquées, les tests plus difficiles et la maintenance plus lente

Plan concret:
1. Créer des repositories dédiés par domaine:
   - `request_repository.dart`
   - `student_profile_repository.dart`
   - `report_repository.dart`
2. Déplacer les requêtes Firestore hors des widgets
3. Centraliser la normalisation des statuts et des rôles dans des enums ou constantes métiers
4. Isoler la génération PDF dans un service dédié
5. Ajouter des tests unitaires sur:
   - parsing des modèles
   - normalisation des statuts
   - règles de filtrage par rôle et région

Bénéfices attendus:
- écrans plus lisibles
- moins de duplication
- meilleure stabilité
- onboarding plus simple
- base plus propre pour ajouter des fonctionnalités

## Améliorations recommandées ensuite

- Corriger les problèmes d'encodage UTF-8 dans les fichiers source
- Harmoniser les valeurs de statuts et de rôles pour éviter les variantes (`rejeté`, `rejete`, `en attente`, `en_attente`, etc.)
- Ajouter un jeu minimal de tests automatisés
- Mettre en place une stratégie de logs plus propre entre debug et production
- Nettoyer les fichiers parasites du dépôt (`firebase-debug.log`, `$null`, dossiers temporaires si non utilisés)

## Commandes utiles

```bash
flutter analyze
flutter test
flutter build web
firebase deploy
```

## Statut du projet

Le projet est déjà fonctionnel sur le plan métier, mais il est encore en phase de consolidation technique. La base produit est là; la priorité suivante doit être la stabilisation, la factorisation et les tests.
