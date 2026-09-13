# Ressources audio — Adhan

## Fichiers attendus (phase 3)

Placer ici les fichiers du catalogue `Muezzin.catalog` :

| Fichier          | Voix           |
|------------------|----------------|
| `makkah.mp3`     | Makkah         |
| `madinah.mp3`    | Madinah        |
| `alafasy.mp3`    | Mishary Alafasy|
| `abdul-basit.mp3`| Abdul Basit    |

## ⚠️ Licence et droits d'auteur

**Ne commitez que des fichiers dont vous détenez les droits**
(enregistrements personnels, domaine public, licence explicite).
Les enregistrements commerciaux de Muadhins célèbres sont protégés :
prévoyez soit une licence, soit un enregistrement original, soit un
téléchargement optionnel depuis une source autorisée (prévu en phase 3 :
cache + suppression).

## Son de notification (< 30 s)

Les sons de notification iOS sont limités à **moins de 30 secondes**
(`aiff`, `wav` ou `caf`, voir `docs/IOS_LIMITATIONS.md`). Prévoir un extrait
court dédié, ex. `adhan-short.caf`, distinct des fichiers complets ci-dessus.

## Téléchargement (phase 3)

Ordre de résolution : fichier bundle → cache téléchargé → téléchargement.
- Cache : `Application Support/Adhan/` (exclu de la sauvegarde iCloud,
  contenu re-téléchargeable), supprimable voix par voix depuis Réglages.
- Pour activer le téléchargement d'une voix : renseigner `remoteURL` dans
  `Muezzin.catalog` (URL https stable vers le MP3, source autorisée).
- Téléchargement au premier plan avec progression (pas de session
  d'arrière-plan en v1 : l'app reste ouverte pendant le transfert).
