import MapKit
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
    let onHold: () -> Void
    let onContinue: (Int) -> Void
    let onStop: () -> Void
    let onDone: () -> Void
    let onPreviewWalkingRoute: () -> Void

    @State private var isConfirmingStop = false
    @State private var isChoosingContinuation = false
    @State private var heldPlace: HeldPlace?

    var body: some View {
        // The card sizes to its content and only scrolls once the content no longer fits the space
        // the map leaves it; the text size no longer decides whether it can scroll.
        ViewThatFits(in: .vertical) {
            content
            ScrollView(.vertical, showsIndicators: false) {
                content
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
        .task(id: heldCoordinateKey) {
            await resolveHeldPlace()
        }
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
        .sheet(isPresented: $isChoosingContinuation) {
            RouteContinueSheet(session: session) { additionalLaps in
                isChoosingContinuation = false
                onContinue(additionalLaps)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isHolding {
            heldContent
        } else {
            runContent
        }
    }

    private var runContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            ProgressView(value: session.lapProgress)
                .tint(progressTint)

            metrics

            controls

            footer
        }
        .padding(.bottom, 4)
    }

    /// A held point is a place, not a paused run: it names where the iPhone is, and offers the two
    /// things that make sense from there — restoring the real location or walking on preview.
    private var heldContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(heldTitle)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(heldSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 10) {
                Button(role: .destructive) {
                    isConfirmingStop = true
                } label: {
                    Label("Stop & Restore".localized, systemImage: "stop.fill")
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.red)
                .accessibilityLabel("Stop & Restore".localized)

                Button(action: onPreviewWalkingRoute) {
                    Label("Preview Walking Route".localized, systemImage: "figure.walk")
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("Preview Walking Route".localized)
            }

            footerText(
                String(
                    format: String(localized: "This iPhone is using %@. Stop & Restore ends the simulation and restores its real location."),
                    heldTitle
                )
            )
        }
        .padding(.bottom, 4)
    }

    private var isHolding: Bool {
        if case .holding = session.phase { return true }
        return false
    }

    private var heldCoordinateKey: GeoCoordinate? {
        guard isHolding, let coordinate = session.snapshot?.reportedCoordinate else { return nil }
        return coordinate
    }

    private var heldCoordinate: CLLocationCoordinate2D? {
        guard let coordinate = heldCoordinateKey else { return nil }
        return CLLocationCoordinate2D(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    private var heldTitle: String {
        HeldPointLabel.title(
            resolvedName: heldPlace?.name,
            fallback: String(localized: "Held here")
        )
    }

    private var heldSubtitle: String {
        if let address = heldPlace?.address, !address.isEmpty {
            return address
        }
        guard let coordinate = heldCoordinate else { return "" }
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    /// One lookup per held coordinate: the point does not move while held, so this never repeats
    /// per tick.
    private func resolveHeldPlace() async {
        guard let coordinate = heldCoordinate else {
            heldPlace = nil
            return
        }
        guard
            let request = MKReverseGeocodingRequest(
                location: CLLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            )
        else {
            heldPlace = HeldPlace(name: nil, address: nil)
            return
        }

        do {
            let items = try await request.mapItems
            let item = items.first
            heldPlace = HeldPlace(name: item?.name, address: item.flatMap { addressText(for: $0) })
        } catch {
            heldPlace = HeldPlace(name: nil, address: nil)
        }
    }

    private func addressText(for item: MKMapItem) -> String? {
        let candidates = [
            item.address?.shortAddress,
            item.addressRepresentations?.cityWithContext,
            item.address?.fullAddress
        ]
        for candidate in candidates {
            let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !value.isEmpty { return value }
        }
        return nil
    }

    private struct HeldPlace: Equatable {
        let name: String?
        let address: String?
    }

    private var progressTint: Color {
        switch session.phase {
        case .finished:
            .green
        case .holding:
            .orange
        case .idle, .preparing, .running, .paused, .stopping, .failed:
            .blue
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

                Text(phaseTitle.localized)
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
        if let trips = session.tripCount, let index = session.tripIndex {
            return RouteRunMetric(
                title: "Trips",
                value: "\(index)/\(trips)",
                symbol: "arrow.left.arrow.right"
            )
        }
        if session.isOpenContinuousRun {
            // No total to divide by: report the trips already completed.
            return RouteRunMetric(
                title: "Trips",
                value: "\(session.completedLaps)",
                symbol: "arrow.left.arrow.right"
            )
        }
        return RouteRunMetric(title: "Laps", value: "\(session.completedLaps)", symbol: "repeat")
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
        case .holding:
            EmptyView()
        case .finished:
            VStack(spacing: 10) {
                primaryButton(title: "Hold Here", symbol: "hand.raised.fill", action: onHold)
                primaryRow {
                    continueButton(prominent: false)
                    secondaryButton(title: "Finish & Restore", symbol: "checkmark", action: onDone)
                }
            }
        case .stopping:
            statusRow("Restoring this iPhone's real location…")
        }
    }

    private func startButton(title: String, symbol: String) -> some View {
        Button(action: onStart) {
            Label(title.localized, systemImage: symbol)
                .frame(maxWidth: .infinity, minHeight: 46)
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
                if isPaused {
                    holdButton(showTitle: true)
                }
                stopButton(showTitle: true)
            }
        } else if isPaused {
            VStack(spacing: 10) {
                pauseButton(isPaused: true)
                HStack(spacing: 10) {
                    holdButton(showTitle: true)
                    stopButton(showTitle: false)
                }
            }
        } else {
            HStack(spacing: 10) {
                pauseButton(isPaused: false)
                stopButton(showTitle: false)
            }
        }
    }

    private func primaryButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title.localized, systemImage: symbol)
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel(title.localized)
    }

    /// "Continue Run" asks for a lap count unless the run loops forever, which has no count to
    /// ask for.
    @ViewBuilder
    private func continueButton(prominent: Bool) -> some View {
        if prominent {
            continueAction.buttonStyle(.borderedProminent)
        } else {
            continueAction.buttonStyle(.bordered)
        }
    }

    private var continueAction: some View {
        Button(action: startContinuation) {
            Label("Continue Run".localized, systemImage: "arrow.triangle.2.circlepath")
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .controlSize(.large)
        .accessibilityLabel("Continue Run".localized)
    }

    private func startContinuation() {
        if session.continuationPlan(additionalLaps: 1) == nil {
            onContinue(1)
        } else {
            isChoosingContinuation = true
        }
    }

    private func secondaryButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title.localized, systemImage: symbol)
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel(title.localized)
    }

    private func holdButton(showTitle: Bool) -> some View {
        Button(action: onHold) {
            if showTitle {
                Label("Hold Here".localized, systemImage: "hand.raised.fill")
                    .frame(maxWidth: .infinity, minHeight: 46)
            } else {
                Image(systemName: "hand.raised.fill")
                    .frame(width: 28)
                    .frame(minHeight: 46)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel("Hold Here".localized)
    }

    private func pauseButton(isPaused: Bool) -> some View {
        Button(action: onTogglePause) {
            Label(
                isPaused ? "Resume" : "Pause",
                systemImage: isPaused ? "play.fill" : "pause.fill"
            )
            .frame(maxWidth: .infinity, minHeight: 46)
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
                    .frame(maxWidth: .infinity, minHeight: 46)
            } else {
                Image(systemName: "stop.fill")
                    .frame(width: 28)
                    .frame(minHeight: 46)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel("Stop")
    }

    /// Lays secondary actions out in a row, or in a column at accessibility text sizes.
    @ViewBuilder
    private func primaryRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                content()
            }
        } else {
            HStack(spacing: 10) {
                content()
            }
        }
    }

    private func statusRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(text.localized)
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
                    ? String(localized: "Your location will move along this route. Keep Roam Control open during the run.")
                    : String(localized: "Pair this iPhone before starting a route.")
            )
        case .preparing:
            footerText(String(localized: "Follow the mobile-data guidance if it appears."))
        case .running:
            footerText(String(localized: "Keep Roam Control running. You can use other apps while the run continues."))
        case .paused:
            footerText(String(localized: "Your simulated location is held here until you resume."))
        case .holding:
            // Rendered by `heldContent`, which carries its own explanation.
            EmptyView()
        case .finished:
            if let error = session.errorMessage {
                errorText(error)
            } else {
                footerText(String(localized: "The route finished. Hold here to keep this point, run more laps, or restore your real location."))
            }
        case .stopping:
            footerText(String(localized: "Keep Roam Control open until the real location has been restored."))
        case .failed(let message):
            errorText(message)
        }
    }

    private func footerText(_ text: String) -> some View {
        Text(text.localized)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func errorText(_ text: String) -> some View {
        Text(text.localized)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var phaseTitle: String {
        switch session.phase {
        case .idle: "Route ready"
        case .preparing: "Preparing route"
        case .running: "Running"
        case .paused: "Run paused"
        case .holding: "Held at this point"
        case .finished: "Run finished"
        case .stopping: "Ending run"
        case .failed: "Run unavailable"
        }
    }

    private var phaseSymbol: String {
        switch session.phase {
        case .idle, .preparing, .running: "figure.run"
        case .paused: "pause.circle.fill"
        case .holding: "hand.raised.fill"
        case .finished: "checkmark.circle.fill"
        case .stopping: "location.slash.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var phaseColour: Color {
        switch session.phase {
        case .holding: .orange
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
        return String(format: String(localized: "%lld spm"), Int(snapshot.cadenceStepsPerMinute.rounded()))
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

/// Asks how many more laps to append to a finished run and spells out where the run will end.
private struct RouteContinueSheet: View {
    let session: RouteSessionModel
    let onConfirm: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var additionalLaps = 1

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $additionalLaps, in: 1...50) {
                        HStack {
                            Text("Extra laps".localized)
                            Spacer(minLength: 8)
                            Text("\(additionalLaps)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let plan = session.continuationPlan(additionalLaps: additionalLaps) {
                    Section {
                        Text(summary(of: plan))
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(endpoint(of: plan))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .navigationTitle("Continue Run".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue".localized) { onConfirm(additionalLaps) }
                }
            }
        }
    }

    private func summary(of plan: RouteContinuationPlan) -> String {
        String(
            format: String(localized: "Ran %lld laps. Adding %lld more makes %lld laps in total."),
            plan.completedLaps,
            plan.additionalLaps,
            plan.totalLaps
        )
    }

    private func endpoint(of plan: RouteContinuationPlan) -> String {
        plan.endsAtStart
            ? String(localized: "The run ends back at the start of the route.")
            : String(localized: "The run ends at the far end of the route.")
    }
}

private struct RouteRunMetric: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title.localized, systemImage: symbol)
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
        .accessibilityLabel("\(title.localized), \(value)")
    }
}
