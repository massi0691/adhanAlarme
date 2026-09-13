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
- [ ] **Phase 2** — Calcul des horaires, localisation, villes manuelles
- [ ] **Phase 3** — Moteur Adhan (AVFoundation), Muadhins, lecture complète
- [ ] **Phase 4** — Notifications, rolling schedule, réglages d'alerte
- [ ] **Phase 5** — Méthodes de calcul, Asr, hautes latitudes, ajustements
- [ ] **Phase 6** — Multilingue complet, sélecteur in-app, RTL, kabyle validé
- [ ] **Phase 7** — Tests UI, accessibilité, optimisation, publication

## Audio

Les fichiers Adhan ne sont pas fournis (droits d'auteur) : voir
`Adhan-Alarme/Resources/Adhan/README.md` avant la phase 3.
