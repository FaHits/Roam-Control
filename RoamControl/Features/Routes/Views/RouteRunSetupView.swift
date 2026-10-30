import Foundation
import SwiftUI

struct RouteRunConfiguration: Equatable, Sendable {
    let route: RouteDefinition
    let profile: RunProfile
    let mode: RouteRunMode
}

/// Local persistence for the runner settings shown by `RouteRunSetupView`.
struct RunProfileStore {
    static let storageKey = "routeRunProfile"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> RunProfile {
        guard let data = defaults.data(forKey: Self.storageKey),
              let profile = try? JSONDecoder().decode(RunProfile.self, from: data),
              (try? profile.validate()) != nil else {
            return .running
        }
        return profile
    }

    func save(_ profile: RunProfile) {
        guard (try? profile.validate()) != nil,
              let data = try? JSONEncoder().encode(profile) else {
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }
}

struct RouteRunSetupView: View {
    let route: RouteDefinition
    let isPaired: Bool
    let onRun: (RouteRunConfiguration) -> Void
    let onCancel: () -> Void

    @State private var profile: RunProfile
    @State private var modeSelection: ModeSelection
    @State private var lapCount = 1

    init(
        route: RouteDefinition,
        isPaired: Bool,
        onRun: @escaping (RouteRunConfiguration) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.route = route
        self.isPaired = isPaired
        self.onRun = onRun
        self.onCancel = onCancel
        _profile = State(initialValue: RunProfileStore().load())
        _modeSelection = State(initialValue: route.isClosed ? .continuous : .once)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    routeHeader
                    profileCard
                    modeCard

                    if let message = startBlockingMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button("Start Run") {
                        start()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(startBlockingMessage != nil)
                }
                .padding(18)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Run Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .onDisappear {
            RunProfileStore().save(profile)
        }
    }

    private var routeHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(route.name)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text(route.isClosed ? "Closed route" : "Open route")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Run Profile")
                .font(.headline)

            settingSlider(
                title: "Speed",
                value: $profile.targetSpeedMetersPerSecond,
                range: 1.0...6.0,
                step: 0.1,
                valueText: String(format: "%.1f m/s", profile.targetSpeedMetersPerSecond)
            )
            settingSlider(
                title: "Cadence",
                value: $profile.targetCadenceStepsPerMinute,
                range: 120.0...210.0,
                step: 1.0,
                valueText: String(format: "%.0f spm", profile.targetCadenceStepsPerMinute)
            )
            settingSlider(
                title: "Speed Variation",
                value: $profile.speedVariationFraction,
                range: 0.0...0.15,
                step: 0.01,
                valueText: String(format: "%.0f%%", profile.speedVariationFraction * 100)
            )
            settingSlider(
                title: "Cadence Variation",
                value: $profile.cadenceVariationFraction,
                range: 0.0...0.15,
                step: 0.01,
                valueText: String(format: "%.0f%%", profile.cadenceVariationFraction * 100)
            )
            settingSlider(
                title: "GPS Jitter",
                value: $profile.gpsJitterRadiusMeters,
                range: 0.0...5.0,
                step: 0.1,
                valueText: String(format: "%.1f m", profile.gpsJitterRadiusMeters)
            )
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mode")
                .font(.headline)

            if route.isClosed {
                Picker("Mode", selection: $modeSelection) {
                    ForEach(ModeSelection.allCases, id: \.self) { selection in
                        Text(selection.rawValue).tag(selection)
                    }
                }
                .pickerStyle(.segmented)

                if modeSelection == .laps {
                    Stepper("Laps: \(lapCount)", value: $lapCount, in: 1...100)
                }
            } else {
                Text("Once")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func settingSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer(minLength: 12)
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
        }
    }

    private var geometry: RouteGeometry? {
        try? RouteGeometry(points: route.points, isClosed: route.isClosed)
    }

    private var mode: RouteRunMode {
        switch modeSelection {
        case .once:
            return .once
        case .continuous:
            return .continuous
        case .laps:
            return .laps(lapCount)
        }
    }

    private var startBlockingMessage: String? {
        if !isPaired {
            return "Pair this iPhone before starting a run."
        }
        guard geometry != nil else {
            return "This route cannot be run."
        }
        guard (try? profile.validate()) != nil else {
            return "These run settings are invalid."
        }
        guard (try? mode.validated()) != nil else {
            return "This run mode is invalid."
        }
        return nil
    }

    private func start() {
        guard startBlockingMessage == nil else {
            return
        }
        RunProfileStore().save(profile)
        onRun(RouteRunConfiguration(route: route, profile: profile, mode: mode))
    }
}

private extension RouteRunSetupView {
    enum ModeSelection: String, CaseIterable, Hashable {
        case once = "Once"
        case continuous = "Continuous"
        case laps = "Laps"
    }
}
