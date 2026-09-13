# Architecture — Adhan Alarme

## 1. Vue d'ensemble

```
SwiftUI View
    ↓ (état observable)
ViewModel (@Observable, @MainActor)
    ↓
Use Case (valeur Sendable, logique pure)
    ↓
Repository (protocole Sendable)
    ↓
Provider : API externe / cache local / calcul local / mosquée
```

Règles :

- **Aucune logique métier dans les Views** (composition + style uniquement).
- **Domaine 100 % valeur** : `struct`/`enum` `Sendable`, `Codable`, `Hashable`.
- **Injection de dépendances** via `AppContainer` (racine de composition).
  Pas de singleton global.
- `async/await` partout ; pas de completion handler, pas de Combine superflu.
- Zéro force unwrap dans le code de production.

## 2. Arborescence

```
Adhan-Alarme/
├── Adhan_AlarmeApp.swift          # Point d'entrée (@main)
├── PrivacyInfo.xcprivacy          # Manifeste requis (UserDefaults)
├── App/
│   └── AppContainer.swift          # DI : production / preview
├── Domain/
│   ├── Models/                     # Prayer, PrayerTimes, Muezzin, réglages…
│   ├── Protocols/                  # Repository, Provider, Alert, Playback, Settings
│   └── UseCases/                   # GetPrayerTimes, GetNextPrayer
├── Data/
│   ├── Mocks/                      # Dépôt simulé + fixtures de preview
│   └── Settings/                   # UserDefaultsSettingsStore
├── Presentation/
│   ├── DesignSystem/               # Couleurs, typo, espacements, composants
│   ├── Formatting/                 # CountdownFormatter (pur, testé)
│   └── Home/                       # HomeView + HomeViewModel
└── Resources/
    ├── Localizable.xcstrings       # fr / en / ar
    ├── Localization/kab.lproj/Kabyle.strings  # Kabyle, table séparée (phase 6)
    └── Adhan/                      # Fichiers audio (phase 3, voir README)
```

Les groupes Xcode sont **synchronisés** : tout fichier ajouté au dossier est
compilé automatiquement, sans modification du `.pbxproj`.

## 3. Concurrence (Swift 6)

- Cible compilée en **Swift 6.0** (`SWIFT_VERSION = 6.0`).
- **Isolation par défaut conservée** : `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  (valeur du template). Justification :
  - toute l'UI et les ViewModels partagent un seul domaine d'isolation,
    ce qui rend la DI triviale à compiler en mode strict ;
  - le calcul d'horaires coûte des microsecondes : aucun acteur background
    n'est nécessaire (ni aujourd'hui ni en phase 2) ;
  - les appels réseau (`URLSession.async`) suspendent sans bloquer le MainActor.
- Les protocoles traversant les couches (`PrayerTimesRepository`,
  `PrayerTimesProvider`, `PrayerAlertService`, `AdhanPlaybackService`)
  sont `Sendable` : les implémentations futures (acteurs audio/notifications)
  resteront vérifiables par le compilateur.
- `SettingsStoring` est volontairement confiné au `MainActor` (écritures UI).

## 4. Persistance

- Phase 1 : `UserDefaultsSettingsStore` — `AppSettings` encodé en JSON
  sous la clé **versionnée** `app.settings.v1`. Toute évolution du schéma
  change la clé (migration simple, sans corruption).
- `PrivacyInfo.xcprivacy` déclare `NSPrivacyAccessedAPICategoryUserDefaults`
  (motif `CA92.1`), **exigé par l'App Store** dès l'usage des UserDefaults.
- Évaluation phase 2 : SwiftData pour les villes multiples et le cache
  d'horaires ; UserDefaults conservé pour les réglages simples.

## 5. Localisation

| Langue  | Code  | Mécanisme phase 1                    |
|---------|-------|--------------------------------------|
| Français| `fr`  | `Localizable.xcstrings` ✅            |
| English | `en`  | `Localizable.xcstrings` (source) ✅   |
| العربية | `ar`  | `Localizable.xcstrings` + RTL auto ✅ |
| Kabyle  | `kab` | `kab.lproj/Kabyle.strings` (provisoire, non branché) |

- Les vues utilisent **uniquement des clés** (`Text("home.nextPrayer")`),
  jamais de texte en dur. Les clés dynamiques passent par
  `Text(LocalizedStringKey(...))` (un `String` variable serait verbatim).
- Le kabyle n'est pas une langue système iOS : la phase 6 ajoutera un
  sélecteur in-app (`AppLanguage`) et un chargeur dédié lisant explicitement
  la table `Kabyle` depuis le `.lproj`. Ce nom de table est obligatoire :
  Xcode interdit la coexistence d'un catalogue `.xcstrings` avec une table
  `.strings` du même nom (`Localizable`).
- Les traductions kabyles actuelles sont **provisoires** : validation par
  un locuteur natif requise avant publication.

## 6. Points d'extension par phase

| Phase | Branchement prévu |
|-------|-------------------|
| 2 | `PrayerTimesRepository` réel ; `PrayerTimesProvider` (API/calcul) ; `CoreLocation` + villes ; `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` |
| 3 | `AdhanPlaybackService` (AVFoundation) ; fichiers `Resources/Adhan/` ; mode Background Audio + interruptions |
| 4 | `PrayerAlertService` (UserNotifications) ; rolling schedule (limite 64) ; `INFOPLIST_KEY_NSUserNotificationsUsageDescription` |
| 5 | Paramètres astronomiques de `CalculationMethod` ; UI Réglages (clés `method.*`, `asr.*`, `highLatitude.*` déjà prévues) |
| 6 | Sélecteur de langue in-app ; chargeur kabyle ; validation RTL |
| 7 | UI tests ; audit VoiceOver/Dynamic Type ; passage éventuel du déploiement à iOS 18 |

## 7. Cible de déploiement

`IPHONEOS_DEPLOYMENT_TARGET = 26.5` (valeur du template, iOS actuel).
**Recommandation avant publication** : abaisser à **iOS 18** (ou 17 minimum
pour `@Observable`) afin d'élargir le parc installé, après vérification
dans Xcode qu'aucune API exclusive à iOS 26 n'est utilisée.
