import Foundation
import SwiftUI

/// In-app language override (D-015). iOS reads `AppleLanguages` when the app starts,
/// so a new choice applies after the app is restarted.
enum AppLanguage: String, CaseIterable {
    case automatic
    case english = "en"
    case ukrainian = "uk"

    static let storageKey = "appLanguage"

    /// Language names stay in their own language, the way iOS shows them.
    var title: Text {
        switch self {
        case .automatic: Text("Automatic (iPhone language)")
        case .english: Text(verbatim: "English")
        case .ukrainian: Text(verbatim: "Українська")
        }
    }

    func apply(to defaults: UserDefaults = .standard) {
        if self == .automatic {
            // Removing the app-level value falls back to the iPhone's language list.
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([rawValue], forKey: "AppleLanguages")
        }
    }
}
