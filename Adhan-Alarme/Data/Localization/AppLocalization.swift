import Foundation

/// Résolution des chaînes dans la langue de l'app (pas forcément celle de
/// l'appareil, quand l'utilisateur force une langue in-app).
/// fr/en/ar : `.lproj` générés depuis le catalogue ; kab : `kab.lproj`
/// embarqué (table `Kabyle`) ; repli : bundle hôte (langue appareil).
enum AppLocalization {
    /// Nom du `.lproj` pour une langue explicite (`nil` = système).
    static func lprojName(for language: AppLanguage) -> String? {
        switch language {
        case .system: nil
        case .french: "fr"
        case .english: "en"
        case .arabic: "ar"
        case .kabyle: "kab"
        }
    }

    /// Table strings : `Kabyle` pour le kabyle, `nil` (Localizable) sinon.
    static func tableName(for language: AppLanguage) -> String? {
        language == .kabyle ? "Kabyle" : nil
    }

    /// Bundle de langue explicite (`nil` si absent → repli appelant).
    static func languageBundle(named lproj: String, in host: Bundle = .main) -> Bundle? {
        host.path(forResource: lproj, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    /// Chaîne `key` dans `language` (repli : hôte, qui renvoie la clé
    /// si absente partout — jamais de crash, jamais de vide).
    static func string(forKey key: String, language: AppLanguage, host: Bundle = .main) -> String {
        if let lproj = lprojName(for: language),
           let bundle = languageBundle(named: lproj, in: host) {
            let value = bundle.localizedString(forKey: key, value: nil, table: tableName(for: language))
            if value != key { return value }
        }
        return host.localizedString(forKey: key, value: nil, table: nil)
    }
}
