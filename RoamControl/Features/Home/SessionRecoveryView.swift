import SwiftUI

struct SessionRecoveryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let recovery: SessionRecoveryRecord
    let isPaired: Bool
    let isResuming: Bool
    let isRestoring: Bool
    let errorMessage: String?
    let onResume: () -> Void
    let onRestore: () -> Void
    let onAlreadyRestored: () -> Void
    let onCancel: () -> Void

    @State private var isConfirmingRestore = false

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: false) {
                    content
                }
                .frame(maxHeight: 540)
            } else {
                content
            }
        }
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 20 : 26)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: 520)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 28, y: 12)
        .confirmationDialog(
            "Restore this iPhone's real location?",
            isPresented: $isConfirmingRestore,
            titleVisibility: .visible
        ) {
            Button("Restore Real Location", role: .destructive, action: onRestore)
            Button("Keep Recovery Options", role: .cancel) {}
        } message: {
            Text("Roam Control will reconnect only long enough to clear the simulated location. It will not start a new location or walking session.")
        }
    }

    private var content: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: 38, height: 5)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: dynamicTypeSize.isAccessibilitySize ? 66 : 78,
                        height: dynamicTypeSize.isAccessibilitySize ? 66 : 78
                    )

                Image(systemName: recoveryIcon)
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 9) {
                Text("Previous Session Interrupted")
                    .font(.title2.bold())

                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                if recovery.isSavedRoute {
                    recoveryDetail(
                        title: "Route".localized,
                        value: recovery.savedRoute?.name ?? String(localized: "Saved route"),
                        symbol: RouteSymbol.library
                    )

                    if let routeProgressText {
                        recoveryDetail(
                            title: "Progress".localized,
                            value: routeProgressText,
                            symbol: "flag.checkered"
                        )
                    }
                } else {
                    recoveryDetail(
                        title: (recovery.isWalkingRoute ? "Last saved point" : "Last location").localized,
                        value: recovery.lastReportedLocation.name,
                        symbol: "mappin.and.ellipse"
                    )
                }

                if let destination = recovery.destination, recovery.isWalkingRoute {
                    recoveryDetail(
                        title: "Destination".localized,
                        value: destination.name,
                        symbol: "flag.checkered"
                    )
                }

                recoveryDetail(
                    title: "Last active".localized,
                    value: recovery.updatedAt.formatted(date: .abbreviated, time: .shortened),
                    symbol: "clock"
                )
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            if isResuming || isRestoring {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(isRestoring ? "Restoring this iPhone's real location…" : "Preparing the route…")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)

                Button("Cancel Restoration", role: .cancel, action: onCancel)
                    .foregroundStyle(.secondary)
            } else {
                Button(action: onResume) {
                    Label(resumeTitle, systemImage: resumeSystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isPaired)

                Button(role: .destructive) {
                    isConfirmingRestore = true
                } label: {
                    Label("Restore Real Location", systemImage: "location.slash.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!isPaired)

                Button("My Real Location Is Already Back", action: onAlreadyRestored)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !isPaired {
                Label("Pair this iPhone before resuming or restoring the session.", systemImage: "iphone.and.arrow.forward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage {
                Text(errorMessage.localized)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Restoring reconnects only long enough to clear the simulated location. Nothing starts automatically. Keep Roam Control open until it finishes.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summaryText: String {
        if recovery.isSavedRoute {
            return String(localized: "Roam Control closed before the saved route run ended. Resume the route from the last saved point or restore this iPhone's real location.")
        }

        if let destination = recovery.destination, recovery.isWalkingRoute {
            return String(format: String(localized: "Roam Control closed before it could confirm that the simulated walk to %@ ended. Continue from the last saved point or restore this iPhone's real location."), destination.name)
        }

        return String(format: String(localized: "Roam Control closed before it could confirm that the simulated location at %@ ended. Choose what this iPhone should do next."), recovery.lastReportedLocation.name)
    }

    private var resumeTitle: String {
        if recovery.isSavedRoute {
            return String(localized: "Resume Route Run")
        }
        return recovery.isWalkingRoute ? String(localized: "Resume Walking") : String(localized: "Resume Location")
    }

    private var resumeSystemImage: String {
        if recovery.isSavedRoute {
            return "figure.run"
        }
        return recovery.isWalkingRoute ? "figure.walk" : "arrow.clockwise"
    }

    private var recoveryIcon: String {
        if recovery.isSavedRoute {
            return RouteSymbol.library
        }
        return recovery.isWalkingRoute ? "figure.walk.motion" : "location.fill"
    }

    private var routeProgressText: String? {
        guard let progress = recovery.routeProgress else { return nil }
        guard let lapFraction else {
            return String(format: String(localized: "%lld completed laps"), progress.completedLaps)
        }
        let percentage = "\(Int((lapFraction * 100).rounded()))%"
        return String(format: String(localized: "%lld completed · %@ of lap"), progress.completedLaps, percentage)
    }

    private var lapFraction: Double? {
        guard
            let progress = recovery.routeProgress,
            let route = recovery.savedRoute,
            let geometry = try? RouteGeometry(points: route.points, isClosed: route.isClosed),
            geometry.totalDistance > 0
        else { return nil }

        return min(max(progress.distanceInLap / geometry.totalDistance, 0), 1)
    }

    private func recoveryDetail(title: String, value: String, symbol: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: symbol)
                        .foregroundStyle(.blue)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.caption.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 11) {
                    Image(systemName: symbol)
                        .foregroundStyle(.blue)
                        .frame(width: 22)

                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    Text(value)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}
