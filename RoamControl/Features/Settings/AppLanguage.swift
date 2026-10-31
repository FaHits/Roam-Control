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

    /// The language iOS will use the next time the app launches.
    ///
    /// `Bundle.main` resolves its localisations once at launch, so it cannot
    /// report a language the app has not restarted into. The choice is therefore
    /// derived from the `AppleLanguages` override that `apply(to:)` writes; with
    /// no override the system preference list is used.
    static func effective(
        from defaults: UserDefaults = .standard,
        systemIdentifiers: [String] = Locale.preferredLanguages
    ) -> AppLanguage {
        effective(
            overrideIdentifiers: defaults.object(forKey: appleLanguagesKey) as? [String],
            systemIdentifiers: systemIdentifiers
        )
    }

    /// Pure form of `effective(from:systemIdentifiers:)`.
    static func effective(
        overrideIdentifiers: [String]?,
        systemIdentifiers: [String] = Locale.preferredLanguages
    ) -> AppLanguage {
        matching(identifiers: overrideIdentifiers ?? systemIdentifiers)
    }

    /// Maps an `AppleLanguages` preference list to the closest supported language.
    static func matching(identifiers: [String]) -> AppLanguage {
        guard let preferred = identifiers.first?.lowercased() else { return .system }
        if preferred.hasPrefix("zh-hans") || preferred == "zh-cn" || preferred == "zh-sg" {
            return .simplifiedChinese
        }
        if preferred.hasPrefix("en") {
            return .english
        }
        return .system
    }

    /// True when picking this language changes what iOS will use next launch.
    func requiresRestart(comparedTo current: AppLanguage) -> Bool {
        self != current
    }

    func apply(to defaults: UserDefaults = .standard) {
        if let languageIdentifiers {
            defaults.set(languageIdentifiers, forKey: Self.appleLanguagesKey)
        } else {
            defaults.removeObject(forKey: Self.appleLanguagesKey)
        }
    }
}
