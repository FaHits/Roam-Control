import SwiftUI

@main
struct RoamControlApp: App {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appModel = AppModel()

    init() {
        AppLanguage.recordSystemLanguageIfUnoverridden()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appModel.hasCompletedOnboarding || shouldBypassOnboarding {
                    HomeView(
                        showDeviceSetupInitially: appModel.shouldPresentDeviceSetup
                            || shouldShowDeviceSetupInitially,
                        showSettingsInitially: shouldShowSettingsInitially
                    )
                    .transition(.opacity)
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
                .environment(appModel)
                .preferredColorScheme(preferredColorScheme)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.25),
                    value: appModel.hasCompletedOnboarding
                )
                .onOpenURL { url in
                    appModel.handleOpenURL(url)
                }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appModel.appearance {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private var shouldBypassOnboarding: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--skip-onboarding")
            || shouldShowDeviceSetupInitially
            || shouldShowSettingsInitially
#else
        false
#endif
    }

    private var shouldShowDeviceSetupInitially: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--show-device-setup")
#else
        false
#endif
    }

    private var shouldShowSettingsInitially: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--show-settings")
#else
        false
#endif
    }
}
