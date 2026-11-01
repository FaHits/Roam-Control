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

    /// The language the running app is actually displaying.
    ///
    /// `Bundle` resolves its localisations at launch, so this is the only honest
    /// answer to "what is on screen now" — a stored override that has not been
    /// restarted into does not count.
    static func displayed(in bundle: Bundle = .main) -> AppLanguage {
        let identifiers = bundle.preferredLocalizations
        return matching(identifiers: identifiers.isEmpty ? Locale.preferredLanguages : identifiers)
    }

    /// System language recorded at the last launch that had no override.
    ///
    /// Once an override exists `AppleLanguages` hides the system preference, so
    /// the value is latched while the override is still absent.
    static let systemSnapshotKey = "systemLanguageSnapshot"

    /// `AppleLanguages` cannot answer "is an override in place?": the system
    /// domain carries one for every app, so reading it looks like an override
    /// even on a first launch. The selection this app stored is the honest
    /// signal — it only exists once somebody picked a language.
    static func recordSystemLanguageIfUnoverridden(
        defaults: UserDefaults = .standard,
        systemIdentifiers: [String] = Locale.preferredLanguages
    ) {
        let selection = defaults.string(forKey: storageKey).flatMap(AppLanguage.init(rawValue:))
        guard selection == nil || selection == .system else { return }
        defaults.set(systemIdentifiers, forKey: systemSnapshotKey)
    }

    static func systemLanguageIdentifiers(
        defaults: UserDefaults = .standard,
        systemIdentifiers: [String] = Locale.preferredLanguages
    ) -> [String] {
        (defaults.object(forKey: systemSnapshotKey) as? [String]) ?? systemIdentifiers
    }

    /// True when the selection changes the language the next launch will show.
    static func shouldPromptRestart(
        selecting selection: AppLanguage,
        displayed: AppLanguage,
        systemIdentifiers: [String]
    ) -> Bool {
        let next = selection == .system ? matching(identifiers: systemIdentifiers) : selection
        return next != displayed
    }

    func apply(to defaults: UserDefaults = .standard) {
        if let languageIdentifiers {
            defaults.set(languageIdentifiers, forKey: Self.appleLanguagesKey)
        } else {
            defaults.removeObject(forKey: Self.appleLanguagesKey)
        }
    }
}
