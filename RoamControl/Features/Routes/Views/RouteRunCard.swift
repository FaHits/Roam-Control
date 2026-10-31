import SwiftUI

/// The controls and live telemetry for a manual route run. It only reads `RouteSessionModel` and
/// sends commands back through the callbacks, so no routing logic lives in the view.
struct RouteRunCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let route: RouteDefinition
    let session: RouteSessionModel
    let isPaired: Bool
    let onStart: () -> Void
    let onTogglePause: () -> Void
    let onStop: () -> Void
    let onDone: () -> Void

    @State private var isConfirmingStop = false

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: false) {
                    cardContent
                }
                .frame(maxHeight: 460)
            } else {
                cardContent
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
        .confirmationDialog(
            "Stop the run and restore this iPhone's real location?",
            isPresented: $isConfirmingStop,
            titleVisibility: .visible
        ) {
            Button("Stop & Restore", role: .destructive, action: onStop)
            Button("Keep Running", role: .cancel) {}
        } message: {
            Text("Roam Control will end the route run and restore your real location. Your route progress will be lost.")
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            ProgressView(value: session.lapProgress)
                .tint(session.phase == .finished ? .green : .blue)

            metrics

            controls

            footer
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: phaseSymbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(phaseColour)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(route.name)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text(phaseTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var metrics: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                lapsMetric
                lapMetric
                distanceMetric
                speedMetric
                cadenceMetric
                elapsedMetric
            }
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    lapsMetric
                    lapMetric
                    distanceMetric
                }
                HStack(spacing: 10) {
                    speedMetric
                    cadenceMetric
                    elapsedMetric
                }
            }
        }
    }

    private var lapsMetric: RouteRunMetric {
        RouteRunMetric(title: "Laps", value: "\(session.completedLaps)", symbol: "repeat")
    }

    private var lapMetric: RouteRunMetric {
        RouteRunMetric(title: "Lap", value: lapPercentageText, symbol: "flag.checkered")
    }

    private var distanceMetric: RouteRunMetric {
        RouteRunMetric(title: "Distance", value: distanceText, symbol: "ruler")
    }

    private var speedMetric: RouteRunMetric {
        RouteRunMetric(title: "Speed", value: speedText, symbol: "speedometer")
    }

    private var cadenceMetric: RouteRunMetric {
        RouteRunMetric(title: "Cadence", value: cadenceText, symbol: "figure.run")
    }

    private var elapsedMetric: RouteRunMetric {
        RouteRunMetric(title: "Elapsed", value: elapsedText, symbol: "clock")
    }

    @ViewBuilder
    private var controls: some View {
        switch session.phase {
        case .idle:
            startButton(title: "Start Run", symbol: "figure.run")
        case .failed:
            startButton(title: "Try Again", symbol: "arrow.clockwise")
        case .preparing:
            statusRow("Starting route session…")
        case .running:
            runningControls(isPaused: false)
        case .paused:
            runningControls(isPaused: true)
        case .finished:
            Button(action: onDone) {
                Label("Done", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel("Done")
        case .stopping:
            statusRow("Restoring this iPhone's real location…")
        }
    }

    private func startButton(title: String, symbol: String) -> some View {
        Button(action: onStart) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!isPaired)
        .accessibilityLabel("Start")
    }

    @ViewBuilder
    private func runningControls(isPaused: Bool) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                pauseButton(isPaused: isPaused)
                stopButton(showTitle: true)
            }
        } else {
            HStack(spacing: 10) {
                pauseButton(isPaused: isPaused)
                stopButton(showTitle: false)
            }
        }
    }

    private func pauseButton(isPaused: Bool) -> some View {
        Button(action: onTogglePause) {
            Label(
                isPaused ? "Resume" : "Pause",
                systemImage: isPaused ? "play.fill" : "pause.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel(isPaused ? "Resume" : "Pause")
    }

    private func stopButton(showTitle: Bool) -> some View {
        Button(role: .destructive) {
            isConfirmingStop = true
        } label: {
            if showTitle {
                Label("Stop & Restore", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            } else {
                Image(systemName: "stop.fill")
                    .frame(width: 28)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel("Stop")
    }

    private func statusRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(text)
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var footer: some View {
        switch session.phase {
        case .idle:
            footerText(
                isPaired
                    ? "Your location will move along this route. Keep Roam Control open during the run."
                    : "Pair this iPhone before starting a route."
            )
        case .preparing:
            footerText("Follow the mobile-data guidance if it appears.")
        case .running:
            footerText("Keep Roam Control running. You can use other apps while the run continues.")
        case .paused:
            footerText("Your simulated location is held here until you resume.")
        case .finished:
            footerText("The route finished. Tap Done to end the session and restore your real location.")
        case .stopping:
            footerText("Keep Roam Control open until the real location has been restored.")
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func footerText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var phaseTitle: String {
        switch session.phase {
        case .idle: "Route ready"
        case .preparing: "Preparing route"
        case .running: "Running"
        case .paused: "Run paused"
        case .finished: "Run finished"
        case .stopping: "Ending run"
        case .failed: "Run unavailable"
        }
    }

    private var phaseSymbol: String {
        switch session.phase {
        case .idle, .preparing, .running: "figure.run"
        case .paused: "pause.circle.fill"
        case .finished: "checkmark.circle.fill"
        case .stopping: "location.slash.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var phaseColour: Color {
        switch session.phase {
        case .finished: .green
        case .failed: .red
        case .idle, .preparing, .running, .paused, .stopping: .blue
        }
    }

    private var lapPercentageText: String {
        let progress = min(max(session.lapProgress, 0), 1)
        return "\(Int((progress * 100).rounded()))%"
    }

    private var distanceText: String {
        let metres = session.totalDistance
        guard metres.isFinite, metres > 0 else { return "0 m" }
        guard metres >= 1_000 else { return String(format: "%.0f m", metres) }
        return String(format: "%.2f km", metres / 1_000)
    }

    private var speedText: String {
        guard let snapshot = session.snapshot, snapshot.speedMetersPerSecond.isFinite else {
            return "—"
        }
        return String(format: "%.1f m/s", snapshot.speedMetersPerSecond)
    }

    private var cadenceText: String {
        guard let snapshot = session.snapshot, snapshot.cadenceStepsPerMinute.isFinite else {
            return "—"
        }
        return "\(Int(snapshot.cadenceStepsPerMinute.rounded())) spm"
    }

    private var elapsedText: String {
        guard let elapsed = session.snapshot?.elapsedTime, elapsed.isFinite, elapsed > 0 else {
            return "0:00"
        }
        let totalSeconds = Int(elapsed.rounded())
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        guard hours > 0 else {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
}

private struct RouteRunMetric: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}
