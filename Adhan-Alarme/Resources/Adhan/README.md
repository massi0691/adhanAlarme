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

## Sources distantes configurées (assabile.com)

Les 4 voix du catalogue téléchargent depuis les liens publics de la page
https://www.assabile.com/adhan-call-prayer (« Listen and download ») :
- Makkah → Ali Ibn Ahmad Mala, Haram (03:34)
- Madinah → Haram de Médine (03:09)
- Mishary Alafasy → Koweït (04:00)
- Abdul Basit → Le Caire (03:20)

⚠️ Droits et conditions : ces fichiers restent hébergés par le site
source ; l'app ne les redistribue pas (téléchargement direct chez
l'utilisateur final, cache local). Vérifiez que cet usage respecte les
conditions du site (bande passante, hotlinking) et les droits des
récitants ; pour la production, privilégiez une autorisation écrite ou
votre propre hébergement. Les URLs se remplacent dans `Muezzin.catalog`.
