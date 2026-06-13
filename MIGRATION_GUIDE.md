# 🔄 Guide de Migration - Unification des Modèles Requêtes

## Objectif
Remplacer les 3 modèles de requêtes actuels par un modèle unique et unifié pour simplifier la maintenance et éviter les incohérences.

**Modèles à remplacer :**
- ❌ `RequestModel` 
- ❌ `SponsorshipRequestModel`
- ❌ `ValidationRequestModel`

**Modèle de remplacement :**
- ✅ `UnifiedRequestModel` (nouveau)

---

## Avant (Situation actuelle)

### Structure fragmentée
```dart
// 3 modèles différents pour 3 collections différentes
requests/             // Demandes générales
sponsorship_requests/ // Demandes de parrainage
validation_requests/  // Historique de validation

// Code dupliqué
RequestModel { id, titre, region, userId, createdAt, ... }
SponsorshipRequestModel { id, titre, region, userId, createdAt, ... } // DUPE!
ValidationRequestModel { id, email, region, statut, createdAt, ... }  // DIFFERENT
```

### Problèmes
- **Duplication** : RequestModel et SponsorshipRequestModel quasi-identiques
- **Incohérence** : 3 parsing DateTime différents
- **Maintenance** : Bug fix x3
- **Tests** : Impossible de tester "les requêtes" génériquement

---

## Après (Avec UnifiedRequestModel)

### Structure unifiée
```dart
// 1 modèle, 3 types
UnifiedRequestModel {
  type: RequestType.general       // ou sponsorship, validation
  statut: 'pending'               // identique pour tous
  
  // Champs communs
  id, titre, region, userId, createdAt, ...
  
  // Champs optionnels par type
  familySituation  // si type=sponsorship
  requestId        // si type=validation
}
```

### Avantages
- **Unique source of truth** : 1 modèle = 1 logique
- **Type-safe** : enum `RequestType` pour éviter les erreurs
- **Cohérent** : même parsing DateTime, même validation
- **Testable** : générique sur UnifiedRequestModel

---

## Plan de Migration

### Phase 1 : Préparation (non-breaking)
✅ Créer `UnifiedRequestModel` avec les 3 types
✅ Ajouter conversions :
   - `UnifiedRequestModel.fromRequestModel(RequestModel)`
   - `UnifiedRequestModel.fromSponsorshipRequestModel(SponsorshipRequestModel)`
   - `UnifiedRequestModel.fromValidationRequestModel(ValidationRequestModel)`

### Phase 2 : Migration progressive
1. **RequestRepository** (déjà ✅) - Peut utiliser les deux
   ```dart
   Future<UnifiedRequestModel?> getUnifiedRequest(String id) async {
     final doc = await _firestore.collection('requests').doc(id).get();
     return UnifiedRequestModel.fromDocument(doc, type: RequestType.general);
   }
   ```

2. **Dashboards** - Remplacer les imports graduellement
   ```dart
   // Avant
   import 'package:madaurore/data/models/request_model.dart';
   
   // Après
   import 'package:madaurore/data/models/unified_request_model.dart';
   ```

3. **Services** - Adapter FirestoreService pour retourner UnifiedRequestModel

4. **Tests** - Écrire tests avec UnifiedRequestModel

### Phase 3 : Cleanup (breaking)
- Supprimer RequestModel
- Supprimer SponsorshipRequestModel
- Supprimer ValidationRequestModel

---

## Guide Conversion

### De RequestModel vers UnifiedRequestModel

**Ancien code :**
```dart
RequestModel request = RequestModel.fromDocument(doc);
print(request.titre);
print(request.montant);
```

**Nouveau code :**
```dart
UnifiedRequestModel request = UnifiedRequestModel.fromDocument(
  doc,
  type: RequestType.general,  // <-- Déclarer le type
);
print(request.titre);
print(request.montant);
```

### Créer une requête

**Ancien code :**
```dart
final request = RequestModel(
  id: doc.id,
  titre: 'Demande X',
  statut: 'en attente',
  region: 'Antananarivo',
  createdAt: DateTime.now(),
  userId: '123',
);
```

**Nouveau code :**
```dart
final request = UnifiedRequestModel(
  id: doc.id,
  titre: 'Demande X',
  type: RequestType.general,        // <-- Nouveau
  statut: 'pending',                // Standardisé
  region: 'Antananarivo',
  createdAt: DateTime.now(),
  userId: '123',
);
```

### Utiliser les types

```dart
// Vérifier le type
if (request.type == RequestType.general) {
  print('Demande générale');
  print(request.montant);  // Déjà typé
}

if (request.type == RequestType.sponsorship) {
  print('Demande de parrainage');
  print(request.familySituation);
}

if (request.type == RequestType.validation) {
  print('Trace de validation');
  print(request.requestId);  // Référence à la demande original
}
```

---

## Checklist Migration

### Immédiatement
- [x] Créer `UnifiedRequestModel`
- [ ] Ajouter conversions helper
- [ ] Tester le nouveau modèle

### Court terme (cette sprint)
- [ ] Migration RequestRepository → UnifiedRequestModel
- [ ] Mettre à jour ConseilRequestsList
- [ ] Tester les dashboards

### Moyen terme (prochaines sprints)
- [ ] Migration SponsorshipRequestModel
- [ ] Migration ValidationRequestModel
- [ ] Supprimer anciens modèles

---

## Avantages Immédiats

Même en phase 1, vous gagnez :

✅ **Vérification de type** avec `RequestType` enum
✅ **Validation centralisée** des dates et montants  
✅ **Cohérence** de parsing
✅ **Documentation** claire (champs optionnels par type)
✅ **Évolution future** facile (ajouter champs sans casser les 3 modèles)

---

## Questions Fréquentes

**Q: Faut-il migrer d'un coup ?**
A: Non! Migrez graduellement. Les deux modèles peuvent coexister temporairement.

**Q: Ça va ralentir ?**
A: Non. One model = plus de conversions = plus rapide.

**Q: Et les données Firestore existantes ?**
A: Aucun changement. Le modèle adapte juste la lecture/écriture.

**Q: Comment tester ?**
A: Mock `UnifiedRequestModel.fromMap()` directement. Plus simple.

---

## Prochaines Étapes Après Cette Migration

1. **Ajouter pagination réelle** à RequestRepository
2. **Créer Providers** pour État management (RequestsProvider, etc.)
3. **Refactoriser autres Dashboards** (Admin, Coordinator, Student)
4. **Ajouter ErrorHandler** centralisé pour Firestore errors

---

**Créé le :** 6 avril 2026
**Status :** ✅ Modèle créé, migration planifiée
