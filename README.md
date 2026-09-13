# Adhan Alarme

Application iPhone élégante : horaires de prière précis, alertes fiables
et écoute de l'Adhan complet — dans le strict respect des règles iOS.

## Prérequis

- Xcode 26.5+, iPhone iOS 26.5+ (cible abaissée à iOS 18 avant publication)
- Ouvrir `Adhan-Alarme.xcodeproj`, schéma `Adhan-Alarme`, `⌘R`

## Architecture

SwiftUI → ViewModel (`@Observable`) → Use Case → Repository → Provider.
Détails : [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
Limitations iOS (Adhan auto, 30 s, 64 notifications) :
[`docs/IOS_LIMITATIONS.md`](docs/IOS_LIMITATIONS.md).

## Phases

- [x] **Phase 1** — Architecture, modèles, Design System, écran d'accueil,
  localisation fr/en/ar (+ kabyle provisoire), tests unitaires
- [x] **Phase 2** — Moteur astronomique local, API Aladhan + cache + fallback,
  Core Location one-shot, recherche MapKit, villes sauvegardées, écran Position
- [ ] **Phase 2 (Xcode)** — `⌘B` + `⌘U` : golden tests vs API réelle (±2 min)
- [x] **Phase 3** — Moteur AVPlayer (interruptions, Bluetooth, arrière-plan),
  téléchargement + cache, écran Réglages (voix)
- [ ] **Phase 3 (Xcode)** — `⌘B` + `⌘U` + recette manuelle (§9.6)
- [x] **Phase 4** — Notifications, rolling schedule, réglages d'alerte
- [ ] **Phase 4 (Xcode)** — `⌘B` + `⌘U` + recette manuelle (§10.8)
- [x] **Phase 4-bis** — Hack « Adhan long » expérimental (opt-in, notifications chaînées)
- [ ] **Phase 4-bis (Xcode)** — `⌘B` + `⌘U` + recette manuelle (§12.4)
- [x] **Phase 5** — Méthodes de calcul, Asr, hautes latitudes, ajustements
- [ ] **Phase 5 (Xcode)** — `⌘B` + `⌘U` + recette manuelle (§11.4)
- [x] **Phase 6** — Multilingue complet, sélecteur in-app, RTL, kabyle validé
- [ ] **Phase 6 (Xcode)** — `⌘B` + `⌘U` + recette manuelle (§13.5)
- [x] **Design** — Couleurs marque (émeraude/doré), apparence Clair/Sombre/Système, accueil façon Mawaqit, icônes prières
- [ ] **Design (Xcode)** — `⌘B` + `⌘U` + recette visuelle (§14.4)
- [ ] **Phase 7** — Tests UI, accessibilité, optimisation, publication

## Audio (phase 3)

Moteur AVPlayer + téléchargement + écran Réglages (voix).
Les fichiers Adhan ne sont pas fournis (droits d'auteur) : bundle,
`remoteURL` ou MP3 de test — voir
`Adhan-Alarme/Resources/Adhan/README.md`.

## Alertes (phase 4)

Planification locale glissante (7 jours, 42 notifications max),
modes par prière (Adhan / notification / silencieux), lecture auto
quand l'app est ouverte, action « Écouter », son custom < 30 s
optionnel (`adhan-short.caf`). Détails : §10 d'ARCHITECTURE.
