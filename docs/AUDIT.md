# Audit complet — Adhan Alarme

_Date : 2026-09-13. Périmètre : tout le code (`Adhan-Alarme/`, 78 fichiers),
les tests (20 fichiers, 129 tests), la configuration projet et les docs.
Méthode : relecture des chemins critiques (horaires, localisation, audio,
alertes, persistance), chasse aux signaux faibles (0 `TODO`, 0 force unwrap,
0 `fatalError`, 0 `print` — vérifié par grep), confrontation aux règles iOS._

## 1. Verdict global

**L'app est saine et proche d'être publiable.** Architecture propre (SwiftUI →
`@Observable` → Use Case → Repository → Provider, DI par conteneur),
hors-ligne d'abord (cache → API → calcul local), économe en batterie (GPS
one-shot kilométrique), 129 tests unitaires, 4 langues + RTL, clair/sombre/
système, manifest de confidentialité correct (`UserDefaults`/`CA92.1`).

Il reste **7 points P0 à corriger avant publication** (dont 1 déjà corrigé,
à valider en recette), une dizaine d'améliorations P1 recommandées, et un
gisement de fonctionnalités à forte valeur (widget, Qibla, hijri…).

## 2. Forces (à préserver)

- Moteur astronomique local correct (PrayTimes 2 passes, bornes polaires,
  arrondi minute) + API Aladhan vérifiée par appels réels + cache borné.
- Aucun crash possible repéré : pas de force unwrap, pas de `fatalError`,
  erreurs propagées ou repliées proprement.
- Localisation GPS one-shot (pas de suivi continu), cascade de secours
  GPS → dernière position → ville (jamais d'écran vide sans explication).
- Notifications locales uniquement (aucun serveur, aucune donnée envoyée),
  limite 64 respectée, fuseau de prière propagé, chaînes pré-rendues.
- Audio : session `.playback`/`.spokenAudio`, interruptions et casque
  gérés, Now Playing, cache exclu de la sauvegarde iCloud.
- Accessibilité de base présente (Dynamic Type, VoiceOver raisonné,
  contrastes AA) ; splash clair/sombre ; code localisé à 109 clés × 4.

## 3. P0 — Bloquants pré-publication

### P0-1. Autorisation notifications jamais demandée — ✅ CORRIGÉ (`9eb7eed`)
Interrupteur ON par défaut + demande uniquement sur bascule OFF→ON =
autorisation jamais demandée, `schedule()` en échec silencieux, **zéro
notification**. Le fix demande en contexte (lancement, bascule) et rend
l'interrupteur véridique en cas de refus. **Reste : recette réelle**
(dialogue iOS → Autoriser → notification à la prochaine prière).

### P0-2. Alertes périmées après voyage (même jour)
`HomeViewModel.scheduleAlertsIfNeeded` ne replanifie qu'une fois par jour
calendaire (`lastScheduledDayID`). Après un changement de ville/fuseau,
l'affichage se met à jour mais **les alertes restent celles de l'ancien
lieu** jusqu'au lendemain ou à la relance.
- Fichiers : `Presentation/Home/HomeViewModel.swift` (~l.113).
- Fix : signature `lieu + fuseau + jour` (reset si lieu/fuseau change).
- Charge : petit.

### P0-3. Déclencheurs sans fuseau explicite
`PrayerAlertRequestMapper` construit `UNCalendarNotificationTrigger` avec
des composants **sans `timeZone`** → interprétés dans le fuseau appareil
au moment du déclenchement → après un voyage, horaires décalés.
- Fichier : `Data/Alerts/PrayerAlertRequestMapper.swift`.
- Fix : `components.timeZone = request.timeZone` (+ `calendar`).
- Charge : 2 lignes.

### P0-4. « Écouter » sans audio = silence total, aucun feedback
Si aucune voix n'est disponible, l'action « Écouter » échoue dans un
`try?` avalé : l'utilisateur tape, **il ne se passe rien** (même
frustration que le bug ⚙️, mais fonctionnel).
- Fichier : `Data/Alerts/PrayerAlertActionHandler.swift:88`.
- Fix : en cas d'échec, planifier une notification immédiate (« Téléchargez
  une voix dans Réglages ») au lieu de se taire.
- Charge : moyen.

### P0-5. Aucune voix jouable par défaut (droits + fiabilité)
Aucun audio embarqué ; les 4 voix distantes sont des hotlinks
`media.assabile.com` **jamais vérifiés** (ni joignabilité, ni droits
écrits). Installation fraîche = lecture auto impossible (repli bannière).
- Fichier : `Domain/Models/Muezzin.swift` (catalogue).
- Fix recommandé (double) : (a) **import audio personnel** (sélecteur
  Files → `Application Support/Adhan` + entrée « Personnalisée ») : légal
  par construction, simple, très demandé ; (b) vérifier joignabilité et
  droits écrits des liens assabile, sinon les retirer.
- Charge : moyen (import), enquête (droits).

### P0-6. Téléchargement octet par octet
`for try await byte in bytes` = ~5 M suspensions pour 5 Mo : lent,
gourmand en CPU/batterie pour des MP3 de 3–8 Mo.
- Fichier : `Data/Audio/FileSystemMuezzinAudioStore.swift` (~l.133).
- Fix : `URLSessionDownloadTask` + délégué (progression native, reprise
  possible) ou lecture bufferisée.
- Charge : moyen.

### P0-7. Pas de validation post-téléchargement
Un fichier corrompu reste marqué « téléchargé » → échecs de lecture
répétés jusqu'à suppression manuelle.
- Fichiers : `FileSystemMuezzinAudioStore.swift`, `AVPlayerAdhanPlaybackService.swift:90`.
- Fix : sonder `isPlayable` après transfert ; supprimer + erreur affichée
  si illisible.
- Charge : petit.

## 4. P1 — Robustesse et UX (recommandé)

| # | Constat | Fichier(s) | Fix | Charge |
|---|---------|-----------|-----|--------|
| P1-1 | Position GPS résolue en fuseau **appareil** (faux si l'appareil est en manuel) | `ActiveLocationResolver.swift` | Fuseau via `CLPlacemark.timeZone` du géocodage inverse | Moyen |
| P1-2 | `currentCoordinates()` concurrents : 2ᵉ appel écrase la continuation du 1ᵉ (Task suspendue à jamais) | `CoreLocationService.swift` | Sérialiser (file/actor) | Petit |
| P1-3 | Erreur réseau de recherche = « aucun résultat » (indistinguable du 0 match) | `LocationViewModel.swift`, `LocationView.swift` | Propager l'erreur → message dédié | Petit |
| P1-4 | Ajustements manuels inclus dans la clé de cache → appels API refaits pour rien (déjà appliqués post-fetch) | `PrayerTimesCache.swift` | Retirer de l'empreinte | 3 lignes |
| P1-5 | Preview interactive de l'accueil planifie de **vraies** notifications (`scheduleAlertsIfNeeded` + service réel) | `AppContainer.swift` (preview) | Service factice ou garde preview | Petit |
| P1-6 | Permission `.badge` demandée mais **jamais utilisée** (aucun `badge`/`setBadgeCount`) | `LocalPrayerAlertService.swift:36` | Retirer `.badge` des options | 1 ligne |
| P1-7 | Pas de `BGAppRefresh` : sans ouverture pendant 7 jours, plus aucune alerte (planning glissant épuisé) | — (nouveau) | Tâche de fond opportuniste (replanifier si < 48 h restantes) + doc honnête (jamais garanti) | Moyen |
| P1-8 | Texte d'autorisation localisation **en français dur** pour tous (pas de `InfoPlist.strings`) | `project.pbxproj:407,442` | `InfoPlist.strings` fr/en/ar (+ kabyle si iOS le supporte*) | Petit |
| P1-9 | Zéro log en production : un bug terrain est indiagnostiquable | Tous les chemins critiques | `Logger` (OSLog, privacy-aware) sur scheduling/audio/API | Petit |
| P1-10 | Tests UI vides (template `testExample`) ; recettes manuelles §9.6→§14.4 au statut inconnu ; kabyle non validé | `Adhan-AlarmeUITests/`, recettes | Écrire 4–6 scénarios XCUITest ; dérouler la matrice §7 ; faire valider le kabyle | Moyen + user |

\* Le kabyle n'a pas de code iOS officiel : `InfoPlist.strings (kab)` ne
sera pas sélectionné par le système — prévoir fr/en/ar, le kabyle restant
in-app (déjà le cas).

## 5. Propositions — rendre l'app encore plus utile

Classées par ratio valeur/coût (estimation honnête, limites iOS incluses).

1. **Date hijri sur l'accueil** — `Calendar(identifier: .islamic)` natif,
   ~10 lignes, valeur culturelle immédiate. **Quick win.**
2. **Rappel pré-Adhan** (« dans 15 min », délai par prière) — 1 champ de
   préférence + occurrences décalées dans le use case (toujours < 64).
   Forte valeur, coût moyen.
3. **Boussole Qibla** — cap Core Location + formule ortho­domique, 100 %
   hors-ligne. L'écran le plus demandé après les horaires. Coût moyen.
4. **Widget (accueil + verrouillé)** — prochaine prière + compte à rebours
   via calcul local (pas de réseau en widget). WidgetKit, coût moyen.
5. **Mosquées à proximité** (recherche MapKit + itinéraire) — façon
   Mawaqit, données Apple, coût moyen.
6. **Live Activity / Dynamic Island** du compte à rebours — ActivityKit,
   coût moyen, « wow » élevé.
7. **Mode Ramadan** (Imsak/Iftar mis en avant, dates approximatives
   configurables) — présentation + 2 calculs, coût moyen.
8. **Export calendrier (.ics)** — partage des horaires du mois, petit coût.
9. **Raccourcis Siri** (« prochaine prière ») — App Intents, petit-moyen.
10. **Apple Watch** — heures + compte à rebours. Nouvelle target, gros coût.
11. **AlarmKit iOS 26** (alarmes plein écran) — ⚠️ à **prototyper sans
    promesse** : sons customs < 30 s non répétables, pas d'Adhan complet
    garanti (cf. `IOS_LIMITATIONS.md`). Piste, pas engagement.

**Non recommandé** : suivi GPS continu (batterie), notifications push
serveur (coût + privacy pour zéro gain vs local), thèmes cosmétiques
supplémentaires (faible valeur/coût).

## 6. Dette mineure (au fil de l'eau)

- `Muezzin.duration` codée en dur et **jamais lue** (vérifié) : la
  supprimer ou la calculer à la volée.
- Commentaires/docs : `ARCHITECTURE.md` excellent mais redondant avec
  `AUDIT.md` sur l'historique — ne pas dupliquer, renvoyer.
- `MockPrayerTimesRepository` / `PreviewFixtures` dans le main target :
  envisager leur bascule côté tests si le binaire grossit (pas urgent).
- Tap ⚙️ intermittent toujours non expliqué (piste scroll réfutée par
  test) : reprendre avec réponses aux 3 questions de diagnostic ou
  instruments (vieil iPhone ? geste ?).

## 7. Matrice de recette consolidée (avant publication)

- [ ] P0-1 : dialogue iOS → Autoriser → notif à la vraie prochaine prière
      (app tuée, fond, premier plan + voix téléchargée = Adhan complet).
- [ ] P0-2/P0-3 : simuler un voyage (ville + fuseau) → alertes replanifiées
      le jour même, à la bonne heure absolue.
- [ ] P0-4/P0-5 : install fraîche sans voix → « Écouter » donne un feedback,
      jamais un silence.
- [ ] P0-6/P0-7 : téléchargement 4 voix (Wi-Fi + 4G, interruption en cours,
      fichier corrompu simulé).
- [ ] P1-7 : 7 jours sans ouvrir (ou date système avancée) → comportement
      documenté.
- [ ] Golden tests API réelle (§9.6), §10.8, §11.4, §12.4, §13.5, §14.4.
- [ ] VoiceOver + Dynamic Type max + arabe RTL + sombre, sur appareil.
- [ ] Kabyle validé par un locuteur (109 clés).
- [ ] `⌘B` + `⌘U` verts sur la tête de branche.

## 8. Roadmap proposée

1. **Stabilisation v1.0** : P0-2→P0-7 + P1-4/P1-6/P1-8/P1-9 (petits) + §7.
2. **Confiance** : P1-2, P1-3, P1-1, P1-7, tests UI (P1-10).
3. **Valeur** : hijri + rappel pré-Adhan + Qibla (v1.1), widget + mosquées
   (v1.2), le reste au fil des retours utilisateurs.
