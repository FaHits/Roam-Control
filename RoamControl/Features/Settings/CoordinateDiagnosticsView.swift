import CoreLocation
import SwiftUI

struct CoordinateDiagnosticsView: View {
    @Environment(AppModel.self) private var appModel

    #if DEBUG
    @State private var probeCandidate: ProbeCandidate = .raw
    @State private var probe = DeviceLocationProbe()
    @State private var probeStatus = "Not injected"
    #endif

    var body: some View {
        List {
            if let target = appModel.selectedTarget {
                Section("Target") {
                    LabeledContent("Name", value: target.name)
                    LabeledContent("Raw", value: Self.coordinates(target.latitude, target.longitude))
                }

                Section {
                    candidateRow(
                        title: "WGS-84 → GCJ-02",
                        coordinate: ChinaCoordinateTransform.wgs84ToGCJ02(
                            latitude: target.latitude,
                            longitude: target.longitude
                        ),
                        from: target
                    )
                    candidateRow(
                        title: "GCJ-02 → WGS-84",
                        coordinate: ChinaCoordinateTransform.gcj02ToWGS84(
                            latitude: target.latitude,
                            longitude: target.longitude
                        ),
                        from: target
                    )
                } header: {
                    Text("Candidate Datums")
                } footer: {
                    Text("Distance is measured from the raw app coordinate. Screenshot this screen, then compare the injected blue dot on both maps.")
                }

                Section("Injection") {
                    LabeledContent("Adapter", value: appModel.deviceSession.coordinateAdapter.conversion.label)
                    LabeledContent("Injected", value: injectedText(for: target))
                }

                #if DEBUG
                probeSection(for: target)
                #endif
            } else {
                Text("Select a location on the map first.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Coordinate Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func injectedText(for target: LocationTarget) -> String {
        let injected = appModel.deviceSession.injectedCoordinate(for: target)
        return Self.coordinates(injected.latitude, injected.longitude)
    }

    private func candidateRow(
        title: String,
        coordinate: CLLocationCoordinate2D,
        from target: LocationTarget
    ) -> some View {
        let distance = CLLocation(latitude: target.latitude, longitude: target.longitude)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        return LabeledContent(title) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(Self.coordinates(coordinate.latitude, coordinate.longitude))
                Text(String(format: "%.1f m away", distance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    #if DEBUG
    private enum ProbeCandidate: String, CaseIterable, Identifiable {
        case raw = "Raw app coordinate"
        case wgsToGCJ = "WGS-84 → GCJ-02"
        case gcjToWGS = "GCJ-02 → WGS-84"

        var id: String { rawValue }
    }

    private func probeSection(for target: LocationTarget) -> some View {
        let candidate = probeCoordinate(for: target)
        return Section {
            Picker("Candidate", selection: $probeCandidate) {
                ForEach(ProbeCandidate.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .onChange(of: probeCandidate) { _, _ in probeStatus = "Not injected" }

            LabeledContent("Candidate", value: Self.coordinates(candidate.latitude, candidate.longitude))
            Button("Inject Probe") { runProbe(for: target) }
            LabeledContent("Status", value: probeStatus)

            if let reading = probe.reading {
                LabeledContent("Readback", value: Self.coordinates(reading.coordinate.latitude, reading.coordinate.longitude))
                LabeledContent("Accuracy", value: String(format: "%.1f m", reading.horizontalAccuracy))
                LabeledContent("Timestamp", value: reading.timestamp.formatted(date: .omitted, time: .standard))
                LabeledContent(
                    "Simulated",
                    value: reading.sourceInformation.map { $0.isSimulatedBySoftware ? "yes" : "no" } ?? "unknown"
                )
                LabeledContent(
                    "Readback→Raw",
                    value: String(
                        format: "%.1f m",
                        reading.distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
                    )
                )
            }

            if let failure = probe.failure {
                Text(failure).foregroundStyle(.red)
            }
        } header: {
            Text("Probe (Debug)")
        } footer: {
            Text("Injects the selected candidate straight to the device, bypassing the adapter. The selected target, history and routes are untouched. Readback arrives after 5 seconds.")
        }
        .accessibilityIdentifier("Probe (Debug) inject single candidate")
    }

    private func runProbe(for target: LocationTarget) {
        let candidate = probeCoordinate(for: target)
        let result = appModel.deviceSession.injectProbeCoordinate(
            latitude: candidate.latitude,
            longitude: candidate.longitude
        )
        probeStatus = String(describing: result)
        guard result == .updated else { return }
        Task {
            try? await Task.sleep(for: .seconds(5))
            probe.requestReading()
        }
    }

    private func probeCoordinate(for target: LocationTarget) -> CLLocationCoordinate2D {
        switch probeCandidate {
        case .raw:
            return target.coordinate
        case .wgsToGCJ:
            return ChinaCoordinateTransform.wgs84ToGCJ02(latitude: target.latitude, longitude: target.longitude)
        case .gcjToWGS:
            return ChinaCoordinateTransform.gcj02ToWGS84(latitude: target.latitude, longitude: target.longitude)
        }
    }
    #endif

    private static func coordinates(_ latitude: Double, _ longitude: Double) -> String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }
}
