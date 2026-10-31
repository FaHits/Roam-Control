import CoreLocation
import SwiftUI

struct CoordinateDiagnosticsView: View {
    @Environment(AppModel.self) private var appModel

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
                    LabeledContent("Adapter", value: DeviceCoordinateAdapter.live.conversion.label)
                    LabeledContent("Injected", value: injectedText(for: target))
                }
            } else {
                Text("Select a location on the map first.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Coordinate Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func injectedText(for target: LocationTarget) -> String {
        let injected = DeviceCoordinateAdapter.live.coordinate(
            latitude: target.latitude,
            longitude: target.longitude
        )
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

    private static func coordinates(_ latitude: Double, _ longitude: Double) -> String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }
}
