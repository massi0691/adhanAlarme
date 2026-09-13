import SwiftUI

/// Couleurs sémantiques : fonds et textes système (clair/sombre auto)
/// + couleurs de marque tirées de l'icône (vert émeraude, blanc, doré),
/// adaptatives via `UIColor(dynamicProvider:)`.
enum DSColors {
    // MARK: - Système (automatiques)

    static let background = Color(UIColor.systemBackground)
    static let groupedBackground = Color(UIColor.systemGroupedBackground)
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    static let primaryText = Color(UIColor.label)
    static let secondaryText = Color(UIColor.secondaryLabel)

    // MARK: - Marque (adaptatives)

    /// Vert émeraude : teinte principale (actions, accents, surlignage).
    static let brand = adaptive(light: 0x0B6B3A, dark: 0x41D18C)
    /// Doré : accents sur fond clair (contraste AA).
    static let gold = adaptive(light: 0x8F6B00, dark: 0xEAC65E)
    /// Doré lumineux fixe : accents sur fond vert profond (carte hero).
    static let goldBright = Color(rgb: 0xE3B94E)
    /// Texte sur fond de marque.
    static let onBrand = Color.white
    /// Surlignage de la prochaine prière (teinte émeraude douce).
    static let nextHighlight = brand.opacity(0.14)

    /// Dégradé émeraude profond de la carte hero (sombre dans les
    /// deux modes, façon Mawaqit : texte blanc + accents dorés).
    static let heroGradient = LinearGradient(
        colors: [
            Color(UIColor(dynamicProvider: { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0x0A3D24) : UIColor(rgb: 0x0C6B3C) })),
            Color(UIColor(dynamicProvider: { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0x04170E) : UIColor(rgb: 0x073D22) })),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Privé

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor(dynamicProvider: {
            $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        }))
    }
}

private extension UIColor {
    /// `0xRRGGBB` → couleur opaque.
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

private extension Color {
    /// `0xRRGGBB` → couleur opaque (sRGB).
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
