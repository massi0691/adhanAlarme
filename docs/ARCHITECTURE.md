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

## 8. Phase 2 — décisions

### 8.1 Fournisseurs d'horaires et politique de fallback

`DefaultPrayerTimesRepository` applique : **cache → API → calcul local**.

- Le cache passe **en premier** (écart assumé au schéma du prompt) :
  les horaires sont déterministes (jour + lieu + méthode), une entrée
  n'est donc jamais périmée. Zéro appel réseau redondant, batterie préservée.
- Tout changement de configuration (méthode, Asr, règle de latitude,
  angles, ajustements) change la clé de cache → nouvel appel API.
- L'API est **contournée** quand des angles personnalisés sont définis
  (format `methodSettings` non vérifiable) : le calcul local garantit
  des résultats cohérents en ligne comme hors-ligne.
- Seuls les succès API sont mis en cache (jamais le calcul local),
  pour préférer l'API dès qu'elle redevient disponible.
- Ajustements : l'API inclut déjà les offsets officiels des méthodes
  (vérifié : Diyanet), on n'y ajoute que les manuels ; le calcul local
  reçoit offsets de méthode + manuels (additionnés, en un seul point).

### 8.2 API Aladhan — paramètres vérifiés le 2026-09-13

Par appels réels (`meta.method.params`, `meta.offset`, échos `school`
et `latitudeAdjustmentMethod`) :

| Méthode | ID | Fajr | Maghrib | Isha |
|---|---|---|---|---|
| Muslim World League | 3 | 18° | coucher | 17° |
| Égyptienne | 5 | 19,5° | coucher | 17,5° |
| Karachi | 1 | 18° | coucher | 18° |
| Umm al-Qura | 4 | 18,5° | coucher | 90 min |
| ISNA | 2 | 15° | coucher | 15° |
| Diyanet | 13 | 18° | coucher | 17° + offsets (−7, +5, +4, +7) |
| Koweït | 9 | 18° | coucher | 17,5° |
| Qatar | 10 | 18° | coucher | 90 min |
| Singapour | 11 | 20° | coucher | 18° |
| Téhéran | 7 | 17,7° | 4,5° | 14° |
| Jafari | 0 | 16° | 4° | 14° |
| UOIF (France, **ajoutée**) | 12 | 12° | coucher | 12° |

`school` : 0 = standard, 1 = Hanafi. `latitudeAdjustmentMethod` :
1 = MiddleOfNight, 2 = OneSeventh, 3 = AngleBased.
Les tests `PrayerCalculatorTests` comparent le moteur local aux valeurs
dorées de l'API (Évry, 13-09-2026, tolérance ±2 min).

### 8.3 Moteur de calcul local

`PrayerCalculator` (+ `SolarCalculator`) : algorithme astronomique
classique (type PrayTimes), mathématiques publiques, sans dépendance.
Toujours disponible hors-ligne. Arrondi à la minute. Robuste aux
régions polaires (termes trigonométriques bornés, garde-fous NaN).

### 8.4 Localisation et villes

- Core Location **one-shot** (`requestLocation`, précision km) : aucun
  suivi continu. Clé `NSLocationWhenInUseUsageDescription` via build
  setting + `InfoPlist.xcstrings` (en/fr/ar).
- Recherche de villes via **MapKit** (`MKLocalSearchCompleter` +
  `MKLocalSearch`) : gratuit, sans clé API, mondial. Fuseau via
  `placemark.timeZone`, secours par géocodage inverse.
- Cascade du résolveur : GPS → dernière position connue → ville active.
- `CityStore` détient villes + ville active (source unique du mode
  manuel) ; réglages migrés v1→v2 sans perte (voir
  `UserDefaultsSettingsStore.LegacySettings`).

### 8.5 Persistance : SwiftData évalué et écarté

Villes (≤ 20), cache (≤ 30 entrées), réglages : structures minuscules,
accès simples, aucune relation. `UserDefaults` + JSON versionné suffit
et reste lisible/testable. SwiftData sera réévalué si le modèle se
complexifie (historique, mosquées favorites…).

### 8.6 Concurrence : ajustement documenté

Le dépôt et `GetPrayerTimesUseCase` ne sont plus `Sendable` : ils
détiennent des magasins MainActor, et tout le flux de données est
sérialisé sur le MainActor (isolation par défaut du projet). Les
protocoles sans dépendance (`PrayerTimesProvider`, services futurs
audio/notifications) restent `Sendable`. Les délégués ObjC
(Core Location, MapKit) utilisent le motif `nonisolated` + relais
`Task { @MainActor in }` avec extraction préalable de valeurs
`Sendable` (pas de capture d'objets non-`Sendable`).
