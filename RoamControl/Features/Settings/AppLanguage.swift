import Foundation
import SwiftUI

/// Language override stored in `UserDefaults` under `appLanguage`.
///
/// iOS resolves `Bundle.main` localisations once at launch, so a change only
/// takes effect after the app is closed and opened again. The app never calls
/// `exit(0)`; the settings screen asks the person to restart.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    static let storageKey = "appLanguage"
    private static let appleLanguagesKey = "AppleLanguages"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .system: "Follow System"
        case .english: "English"
        case .simplifiedChinese: "Simplified Chinese"
        }
    }

    /// Value written to `AppleLanguages`, or `nil` to follow the system.
    var languageIdentifiers: [String]? {
        switch self {
        case .system: nil
        case .english: ["en"]
        case .simplifiedChinese: ["zh-Hans"]
        }
    }

    func apply(to defaults: UserDefaults = .standard) {
        if let languageIdentifiers {
            defaults.set(languageIdentifiers, forKey: Self.appleLanguagesKey)
        } else {
            defaults.removeObject(forKey: Self.appleLanguagesKey)
        }
    }
}
