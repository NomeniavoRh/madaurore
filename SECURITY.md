# 🔐 Sécurité - Flutter Web Madaurore

## Guide de Sécurité pour Flutter Web

### 1. **Protection du Code Source**

#### ✅ Changements Apportés

- ✅ Suppression de la config Firebase hardcodée de `web/index.html`
- ✅ Ajout de `kDebugMode` pour les logs de débogage
- ✅ Suppression automatique des source maps en build release

#### ⚠️ Build Release Sécurisé

**Utiliser le script fourni :**

```bash
# macOS / Linux
./build_web_release.sh

# Windows
.\build_web_release.bat
```

Ce script :
- ✅ Nettoie les builds précédentes
- ✅ Compile en mode release avec obfuscation
- ✅ Supprime les `.map` files du build final
- ✅ Stocke les debug info séparément dans `build/web_debug_info/`

---

### 2. **Gestion des Secrets**

#### Firebase Configuration

**AVANT (❌ NON SÉCURISÉ)** :
```html
<!-- web/index.html - NE JAMAIS FAIRE CECI -->
<script>
  const firebaseConfig = { apiKey: '...', ... };
  firebase.initializeApp(firebaseConfig);
</script>
```

**APRÈS (✅ SÉCURISÉ)** :
- Firebase initialisé par Flutter via `lib/firebase_options.dart`
- Les clés API restent dans les binaires compilés (protégées par minification)

#### Règles Firestore

**OBLIGATOIRE** : Mettre en place des règles d'accès strictes :

```javascript
// firestore.rules - À appliquer en production
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Ne permettre l'accès qu'aux utilisateurs authentifiés
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

### 3. **Checklist Pre-Production**

- [ ] Exécuter `flutter analyze` pour détectes les warnings
- [ ] Build avec `./build_web_release.sh` (ou `.bat` sur Windows)
- [ ] Vérifier l'absence de `.map` files dans `build/web/`
- [ ] Tester le build final localement
- [ ] Vérifier les règles Firestore en console Firebase
- [ ] Déployer avec : `firebase deploy --only hosting`

---

### 4. **Debugging en Production**

Les debug info sont stockés dans `build/web_debug_info/` :

1. Télécharger `flutter_release_unobfuscate_map` depuis Firebase Crashlytics
2. Utiliser : `flutter symbolize --input=crash_log --symbols-dir=build/web_debug_info/`

---

### 5. **Inspection du Navigateur - Prévention**

| Outil | Protection | Notes |
|-------|-----------|-------|
| **DevTools Console** | ✅ Logs masqués (sauf errors) | Pas de `debugPrint()` |
| **DevTools Sources** | ✅ Code obfusqué | Noms variables minifiés |
| **Network Tab** | ✅ `.map` files absents | Pas de source mapping |
| **Application Storage** | ⚠️ Vérifier Firestore Rules | Essentiel ! |

---

### 6. **Commandes Utiles**

```bash
# Analyser pour les warnings de sécurité
flutter analyze

# Build dev (avec source maps pour débogage)
flutter build web --web-release

# Build sécurisé production
./build_web_release.sh

# Déployer sur Firebase Hosting
firebase deploy --only hosting

# Vérifier les source maps
find build/web -name "*.map"
```

---

## ✅ Statut de Sécurité

| Élément | Avant | Après |
|--------|-------|-------|
| Config Firebase exposée | ❌ | ✅ |
| Source maps en production | ❌ | ✅ |
| Debug logs en production | ❌ | ✅ |
| Obfuscation code | ❌ | ✅ |
| Firestore Rules | ⚠️ (À vérifier) | ⚠️ |

---

## 📞 Support

Pour plus d'informations :
- [Flutter Security Best Practices](https://flutter.dev/security)
- [Firebase Security Rules](https://firebase.google.com/docs/rules)
- [Web App Security](https://developer.mozilla.org/en-US/docs/Web/Security)
