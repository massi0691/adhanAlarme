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
  `MKLocalSearch`) : gratuit, sans clé API, mondial. API iOS 26
  (`placemark`/`CLGeocoder` dépréciés) : ville via
  `addressRepresentations.cityName`, pays via `regionName`, fuseau via
  `MKMapItem.timeZone`, secours par `MKReverseGeocodingRequest`.
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

## 9. Moteur audio (phase 3)

### 9.1 Chaîne de résolution
- Ordre : fichier bundle (`Resources/Adhan/`) → cache
  `Application Support/Adhan/` (exclu sauvegarde) → téléchargement
  explicite depuis `Muezzin.remoteURL` (`nil` = bundle uniquement).
- `MuezzinAudioStore` (protocole) / `FileSystemMuezzinAudioStore` :
  `availability()`, `localURL()`, `download()` (`AsyncThrowingStream`
  0.0 → 1.0, écriture par blocs 64 Ko + fichier `.part` + déplacement
  atomique), `deleteDownload()` (jamais le bundle, idempotent).
- Téléchargement au premier plan en v1 (pas de session d'arrière-plan ;
  fichiers de quelques Mo, app ouverte pendant le transfert).

### 9.2 Lecture (`AVPlayerAdhanPlaybackService`, `@MainActor`, `@Observable`)
- Session `.playback` + `.spokenAudio` (voix ; Bluetooth A2DP/AirPlay
  système). Validation `asset.load(.isPlayable)` (+ `.duration` pour
  Now Playing) avant activation de la session.
- Interruptions (appels/Siri) : pause + reprise si `.shouldResume` ;
  débranchement casque : pause (jamais de haut-parleur surprise).
- Fin/échec d'item → `stopped` + désactivation polie
  (`.notifyOthersOnDeactivation`). Observateurs app-lifetime, `[weak self]`.
- État observé en direct par Réglages (`playbackState`).

### 9.3 Arrière-plan et verrouillage
- Capacité `audio` (`INFOPLIST_KEY_UIBackgroundModes`, build setting).
- `AdhanNowPlayingController` : titre localisé (`audio.nowPlayingTitle`),
  play/pause/toggle (casque, CarPlay). Info statique en v1 (pas de
  progression temps réel). Fabrique pure `AdhanNowPlayingInfo` (testée).

### 9.4 Interface Réglages
- Feuille depuis l'accueil (remplace le placeholder) : section voix —
  sélection persistée (`selectedMuezzinID`), statuts
  (incluse/téléchargée/à télécharger/indisponible), téléchargement avec
  progression, suppression, aperçu lecture/pause/reprise/arrêt.
- Erreurs → clés localisées (`audio.error.*`, 6 cas + statuts).

### 9.5 Tests
- `AdhanNowPlayingInfoTests` (fabrique pure),
  `FileSystemMuezzinAudioStoreTests` (cache isolé, `Bundle(url:)` pour
  le bundle, échec réseau déterministe via port local fermé),
  `AVPlayerAdhanPlaybackServiceTests` (moteur réel, WAV silencieux
  synthétisé en code, interruptions/routes postées),
  `SettingsViewModelTests` (doublures, persistance vérifiée par relecture).
- `AdhanNowPlayingController` : câblage fin non testé (effets MediaPlayer).

### 9.6 Recette manuelle
- Audio de test : déposer n'importe quel MP3 renommé `makkah.mp3` dans
  `Resources/Adhan/` (valide le moteur, pas un vrai Adhan), ou renseigner
  `remoteURL` puis télécharger depuis Réglages.
- Écouter (haut-parleur), pause/reprise/arrêt ; passer en arrière-plan
  puis verrouiller → poursuite + titre sur l'écran verrouillé.
- Appel entrant (second téléphone) → pause + reprise auto.
- Bluetooth (enceinte/AirPods) : routage auto ; déconnexion → pause.
- Casque débranché → pause, pas de haut-parleur surprise.
- Voix non disponible → message clair (jamais de crash).

## 10. Alertes locales (phase 4)

### 10.1 Chaîne de planification
- `SchedulePrayerAlertsUseCase` (non isolé, testé) : fenêtre glissante
  7 jours (aujourd'hui + 6), passé ignoré, prières silencieuses ou
  désactivées ignorées. Interrupteur global coupé → `[]` (= annulation).
- Identifiants stables `adhan.<prière>.<AAAAMMJJ>` (jour UTC) :
  replanifier remplace au lieu de dupliquer.
- 7 × 6 = 42 < 64 (limite iOS), garde `prefix(64)` par prudence.
- `PrayerAlertRequestMapper` (pur) : déclencheur calendaire exact
  (année→seconde, fuseau du lieu), non répété (nettoyé après le tir).

### 10.2 Contenu et son
- `PrayerAlertContentFactory` (pure) : chaînes pré-rendues via `localize`
  (locale de l'interface au moment planifié). Mode `.adhan` :
  catégorie `ADHAN_ALERT` + `timeSensitive` ; `.notificationOnly` :
  `.active` + son système ; `.silent` filtré en amont.
- Son custom : extrait < 30 s (`adhan-short.caf`, bundle ou
  `Library/Sounds`, résolu par `LocalPrayerAlertService`), sinon son
  système. Un fichier complet (> 30 s) est refusé par iOS.
- `LocalPrayerAlertService` (`@MainActor`) : autorisation (dont
  provisoire/éphémère), annule-puis-planifie, catégories au init.
  Non `Sendable` (détient `UNUserNotificationCenter`), comme l'audio.

### 10.3 Réponses (délégué)
- `PrayerAlertActionHandler` (`UNUserNotificationCenterDelegate`,
  assigné en production uniquement) : app ouverte + mode Adhan →
  lecture complète AVPlayer, bannière supprimée (l'Adhan EST l'alerte),
  repli bannière + son si échec ; action « Écouter » → lecture de la
  voix de la prière (`muezzinID` du `userInfo`, défaut sinon) ; tap du
  corps → ouvre l'app, sans lecture.
- Swift 6 : valeurs `userInfo` (`String`) extraites AVANT le saut
  `MainActor`, completion handlers système transportés via
  `CompletionBox` (`@unchecked Sendable`, contrat Apple : appelables
  depuis n'importe quel thread, exactement une fois).

### 10.4 Déclencheurs
- Accueil : après chaque chargement réussi, une fois par jour
  (`lastScheduledDayID`) ; bascule globale → replanifie aussitôt ;
  changement de fuseau système → recharge (+ replanifie).
- Réglages : activation (demande système puis planifie), coupure,
  mode par prière, sélection de voix (propagée aux 6 prières en v1,
  embarquée dans le `userInfo`) → replanifient.
- Permission refusée → planification best-effort ignorée, l'UI guide
  vers les Réglages système (lien direct).

### 10.5 Arrière-plan : `BGAppRefresh` écarté (v1)
- La fenêtre de 7 jours couvre une semaine sans ouvrir l'app ; chaque
  lancement/avant-plan recharge et replanifie.
- `BGAppRefresh` n'est pas garanti par iOS (opportuniste, étranglé
  selon l'usage) et exigerait capacité + `BGTaskScheduler` + plist
  pour un gain marginal : écarté en v1, réévaluable en phase 7.

### 10.6 Interface Réglages
- Section alertes : interrupteur global (demande système à
  l'activation), avertissement + lien Réglages système si refusé,
  mode par prière (`Adhan` / `Notification` / `Silencieux`).
- Interrupteur unique partagé avec l'accueil (`globalAdhanEnabled`,
  resynchronisé à la fermeture de la feuille).

### 10.7 Tests
- `SchedulePrayerAlertsUseCaseTests` (horloge UTC figée, dépôt fixe :
  fenêtre, passé, silences, erreurs, interrupteur),
  `PrayerAlertRequestMapperTests` (identifiants, déclencheur, fuseau),
  `PrayerAlertContentFactoryTests` (catégorie, niveau, son, `userInfo`),
  `SettingsViewModelTests` (+ 4 tests : octroi/refus/coupure/mode).
- Non testés : délégué et service système (pas d'init public
  `UNNotification`, autorisation = invite système) → recette manuelle.

### 10.8 Recette manuelle
- `⌘B` + `⌘U` (nouveaux tests verts).
- Fraîche install → Réglages → activer Alertes → invite système ;
  accepter → 42 notifications planifiées (vérifiable via
  `getPendingNotificationRequests` en `lldb`).
- App ouverte à l'échéance → Adhan auto, pas de bannière.
- Verrouillé à l'échéance → bannière + son ; « Écouter » → Adhan
  complet ; tap corps → ouvre l'app sans lecture.
- Mode `Notification` → bannière + son court, pas d'Adhan ;
  `Silencieux` → rien. Bascule accueil OFF → plus rien.
- Permission refusée → message + lien Réglages système.
- Astuce : avancer l'horloge système déclenche les notifications dues.

## 11. Réglages de calcul (phase 5)

### 11.1 Chaîne déjà câblée (phases 1-2)
- `PrayerCalculationConfiguration` (méthode, Asr, haute latitude,
  angles Fajr/Isha, ajustements manuels) → `CalculationParameters`
  (angles effectifs, facteur d'ombre, règle) → `PrayerCalculator`
  (angles par méthode, Maghrib/Isha angulaires ou à intervalle,
  ajustements haute latitude type PrayTimes).
- API Aladhan : `method` (12 méthodes, UOIF = 12), `school` (Asr),
  `latitudeAdjustmentMethod` ; angles personnalisés → contournement
  API, calcul local seul (cohérence en/hors-ligne).
- Dépôt : cache (clé incluant la configuration) → API → local ;
  ajustements méthode (ex. Diyanet) + manuels additionnés.

### 11.2 Interface Réglages (phase 5)
- Section Calcul : méthode (12), Asr, hautes latitudes, angles
  personnalisés (toggle + pas de 0,5°, bornés 5–25°, reprise des
  angles de la méthode à l'activation), ajustements manuels par
  prière (écran dédié, ±30 min, 0 = effacé).
- Tout changement recalcule : recharge accueil à la fermeture de la
  feuille + replanification des alertes (le planificateur relit la
  configuration).

### 11.3 Tests
- `SettingsViewModelTests` (+ 5 : méthode/Asr/règle, angles
  personnalisés + bornes, ajustements). Moteur, API et dépôt déjà
  couverts (phases 1-2, golden tests vs API réelle : recette Xcode).

### 11.4 Recette manuelle
- `⌘B` + `⌘U`.
- Changer de méthode (MWL → UOIF) → Fajr/Isha décalés dès la
  fermeture de Réglages (12° vs 18°/17°).
- Asr Hanafi → Asr retardé ; angles personnalisés → API contournée
  (cohérence en/hors-ligne) ; ajustement +5 Fajr → Fajr +5 min.
- Alertes replanifiées avec les nouveaux horaires (vérifiable en
  `lldb` via `getPendingNotificationRequests`).

## 12. Hack « Adhan long » (phase 4-bis, expérimental, opt-in)

### 12.1 Principe et limites assumées
- iOS limite chaque son de notification à 30 s (OS, incontournable) :
  l'Adhan complet est découpé en segments chaînés (notifications à
  +30 s, ≈ 8 bannières par prière).
- Interrupteur « Adhan long (expérimental) », désactivé par défaut ;
  la voix doit être téléchargée (découpage du fichier local).
- Couverture réduite : ~48 requêtes/jour sur 64 max → ≈ 1 jour
  (le service garde les 64 premières, chronologiques).
- API publique uniquement, aucune règle écrite violée ; toute
  interaction annule la chaîne en cours.

### 12.2 Chaîne technique
- `FileSystemAdhanSegmentStore` : découpe (idempotente, hors MainActor)
  en `.caf` IMA4 dans `Library/Sounds`, `adhan-<voix>-s<k>.caf`.
- `SchedulePrayerAlertsUseCase` : occurrences `.adhan` expansées
  (+30 s, `soundName`/`segmentIndex`, identifiants `.s<k>`) ; sans
  segments prêts, repli notification unique ; `.notificationOnly`
  jamais chaîné.
- Fabrique : `request.soundName` prioritaire sur le son global.
- `cancelChainedSegments` (préfixe jour) appelé par le délégué à
  chaque présentation/interaction : l'ouverture de l'app fait taire
  la chaîne (relais AVPlayer ou bannière).

### 12.3 Tests
- `SchedulePrayerAlertsUseCaseTests` (+ 2 : expansion/espacement/
  identifiants, repli sans segments), `SettingsViewModelTests`
  (+ 2 : voix requise, activation bout-en-bout).
- Découpe réelle et enchaînement sonore : recette manuelle (le
  simulateur ne rend pas fidèlement les sons chaînés).

### 12.4 Recette manuelle
- `⌘B` + `⌘U`.
- Télécharger une voix → activer Adhan long → « Préparation des
  extraits… » puis ~48 notifications en attente (`lldb`).
- Sans voix téléchargée → message clair, pas d'activation.
- À l'échéance (verrouillé) : bannières chaînées + extraits bout à
  bout (≈ 8) ; ouvrir l'app en cours → silence immédiat.
- « Écouter » → Adhan complet AVPlayer, chaîne annulée.
- Désactiver → retour notification unique ; couverture ≈ 1 jour
  (rouvrir l'app quotidiennement).

## 13. Multilingue complet (phase 6)

### 13.1 Catalogue et chargeur
- 104 clés × fr/en/ar (+ kabyle) ; arabe complété (39 clés manquantes).
- `AppLanguage` (système/fr/en/ar/kab) + `LanguageSettings` (source
  observable persistée) + `AppLocalization` (`.lproj` explicites,
  `kab.lproj` table `Kabyle`, replis — jamais de vide).
- UI : `Text` + environnement `locale` (re-résolu au changement) ;
  kabyle : nécessite `kab.lproj` dans les ressources du bundle.

### 13.2 Application et RTL
- App : `.environment(\.locale)` + `.environment(\.layoutDirection)`
  (arabe → RTL). Notifications, Now Playing, ville, ajustements :
  résolus dans la langue de l'app (replanification au changement).
- Audit RTL : alignements adaptatifs partout ; seul glyphe
  directionnel (chevron accueil) basculé selon la direction ;
  compte à rebours en chiffres latins (volontaire, universel).

### 13.3 Kabyle
- Traductions provisoires (rédigées sans locuteur natif) : à valider
  par un kabylophone avant publication (`Kabyle.strings`, 104 clés).

### 13.4 Tests
- `AppLocalizationTests` (mapping, replis), `SettingsViewModelTests`
  (+ 2 : persistance langue, replanification). Chargements positifs
  et rendu RTL : recette manuelle.

### 13.5 Recette manuelle
- `⌘B` + `⌘U`.
- Sélecteur : Système/Français/English/العربية/Taqbaylit → UI
  entière basculée sans redémarrage ; arabe → mise en page RTL
  (chevron accueil miroir, chiffres minuteur latins).
- Notifications + « Écouter » + Now Playing dans la langue choisie
  (replanification auto au changement).
- Kabyle : vérifier `kab.lproj` copié (Target Membership), sinon
  repli silencieux vers la langue appareil.
- Faire valider `Kabyle.strings` par un kabylophone.

## 14. Design (vert émeraude / blanc / doré)

### 14.1 Marque et thèmes
- Couleurs tirées de l'icône : `DSColors` (émeraude `brand`,
  doré `gold`/`goldBright`, encre `brandInk`), adaptatives
  clair/sombre via `UIColor(dynamicProvider:)` (contraste AA).
- Sélecteur in-app Système/Clair/Sombre (`AppAppearance` +
  `AppearanceSettings`, même pattern que la langue) appliqué par
  `.preferredColorScheme` à la racine ; teinte globale émeraude.
- Fond d'accueil : voile vert (pâle en clair, profond en sombre).

### 14.2 Accueil façon Mawaqit
- Carte hero : dégradé émeraude profond, médaillon doré de la
  prière, horaire blanc, compte à rebours en pilule dorée.
- Lignes : médaillon SF Symbols du moment (aube → lune),
  doré pour la prochaine, estompées si passées.
- Icônes natives uniquement (zéro asset) : 60 ips, Dynamic Type,
  RTL et VoiceOver préservés.

### 14.3 Réglages et Position
- En-têtes de sections icônés, icônes de prières dans les
  alertes par prière, Camille au vert de marque.

### 14.4 Recette visuelle
- `⌘B` + `⌘U`, puis accueil en clair/sombre/système + arabe (RTL).
- Bascules langue × apparence sans redémarrage ni flash.
- Dynamic Type maximal : aucune troncature des médaillons.
