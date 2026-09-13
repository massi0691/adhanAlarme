# Limitations iOS — analyse et stratégie

> Vérifié le 2026-09-13 contre la documentation Apple et les retours
> communautaires récents. À revérifier à chaque phase audio/notifications.

## 1. Son de notification : 30 secondes maximum (BLOQUANT pour l'Adhan auto)

- Les sons personnalisés de notification doivent durer **moins de 30 secondes**,
  aux formats `aiff`, `wav` ou `caf` (Linear PCM, IMA/ADPCM, µLaw, aLaw),
  placés dans le bundle ou `Library/Sounds`.
- **Si le fichier dépasse 30 s, iOS joue le son système par défaut.**
  (Doc Apple : "Local and Remote Notification Programming Guide".)
- Conséquence : **une notification locale classique ne peut pas jouer
  un Adhan complet automatiquement.** Toute promesse contraire serait fausse.

## 2. Notifications planifiées : 64 maximum

- Le système ne conserve que les **64 prochaines notifications planifiées**,
  le reste est ignoré (toujours d'actualité).
- Stratégie phase 4 : *rolling schedule* (~7 jours × 6 prières = 42 requêtes),
  renouvelé à chaque ouverture de l'app + via `BGAppRefresh` en best-effort.

## 3. Lecture audio longue : ce qu'iOS permet réellement

| État de l'app | Adhan complet automatique ? |
|---|---|
| Premier plan | ✅ Oui (`AVAudioSession` + `AVPlayer`, interruptions gérées) |
| Arrière-plan avec audio **déjà en cours** | ✅ Poursuite possible (capacité Background Audio) |
| Suspendue / terminée, déclenchement à l'heure exacte | ❌ **Non.** Aucune API ne démarre une lecture longue à une heure précise sans action utilisateur |
| Terminée manuellement par l'utilisateur | ❌ Non (le système ne relance rien) |
| `BGAppRefresh` / `BGProcessingTask` | ⚠️ Fenêtres courtes, horaires non garantis, boucles d'exactitude impossibles — inutilisable pour un Adhan à l'heure exacte |
| Push distant + Notification Service Extension | ⚠️ ~30 s d'exécution, pas de lecture longue fiable ; nécessite un serveur |
| PushKit VoIP | ❌ Interdit hors appels (doit afficher CallKit) — rejet App Store garanti en cas de détournement |

## 4. Stratégie produit retenue (honnête et conforme)

1. **Cas A — notification système** (app fermée) : alerte visuelle + son
   **court** compatible (< 30 s) + action « Écouter l'Adhan » qui ouvre l'app.
2. **Cas B — app active** : le moteur audio joue l'Adhan **complet** du
   Muadhin choisi, avec gestion des interruptions, Bluetooth/AirPods.
3. L'interface **ne promet jamais** un Adhan complet automatique quand
   l'app est fermée ; le texte d'onboarding l'expliquera clairement.

Cette séparation est déjà inscrite dans l'architecture :
`PrayerAlertService` (notifications) ≠ `AdhanPlaybackService` (audio).

## 5. Autres limites à respecter

- **Localisation** : demander `WhenInUse` uniquement (suffisant pour calculer
  les horaires), avec phrase d'usage explicite ; pas de suivi continu
  (batterie + confidentialité). Ne jamais envoyer la position à un serveur
  sans nécessité.
- **Fuseau horaire / changement de jour** : invalider horaires et
  notifications sur `NSSystemTimeZoneDidChange` et changement de ville (phase 2/4).
- **Données de prière** : aucun contenu propriétaire copié ; calcul local
  + API documentées/autorisées uniquement.
