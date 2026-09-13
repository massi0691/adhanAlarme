import SwiftUI

/// Couleurs sémantiques. Basées sur les couleurs système :
/// Dark Mode et Light Mode pris en charge automatiquement.
enum DSColors {
    static let background = Color(UIColor.systemBackground)
    static let groupedBackground = Color(UIColor.systemGroupedBackground)
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    static let primaryText = Color(UIColor.label)
    static let secondaryText = Color(UIColor.secondaryLabel)
    static let nextHighlight = Color.accentColor.opacity(0.14)
}
