import Foundation
import MapKit
import SwiftUI

/// Tap-to-draw editor for a manual route.
///
/// The draft lives in `RouteEditorModel`; this view only maps taps, the closed-loop switch and the
/// buttons onto it, and hands the finished `RouteDefinition` to `onSave`. Storing the route belongs
/// to the caller, so the editor never touches `RouteStore` or `RouteLibraryModel`.
struct RouteEditorView: View {
    let existingRoute: RouteDefinition?
    let onSave: (RouteDefinition) -> Void
    let onCancel: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: RouteEditorModel
    @State private var cameraPosition: MapCameraPosition
    @State private var isConfirmingClear = false

    init(
        existingRoute: RouteDefinition?,
        onSave: @escaping (RouteDefinition) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.existingRoute = existingRoute
        self.onSave = onSave
        self.onCancel = onCancel
        _model = State(initialValue: RouteEditorModel(route: existingRoute))
        _cameraPosition = State(initialValue: Self.editingCamera(for: existingRoute))
    }

    var body: some View {
        @Bindable var model = model

        ZStack {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    if previewCoordinates.count >= 2 {
                        MapPolyline(coordinates: previewCoordinates)
                            .stroke(.blue, lineWidth: 5)
                    }

                    ForEach(Array(model.points.enumerated()), id: \.offset) { index, point in
                        Annotation("Route point \(index + 1)", coordinate: point.clCoordinate) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .onTapGesture { location in
                    guard let coordinate = proxy.convert(location, from: .local) else {
                        return
                    }
                    model.appendPoint(
                        GeoCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    )
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                nameField(text: $model.name)

                Spacer(minLength: 0)

                editorPanel(isClosed: $model.isClosed)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .confirmationDialog(
            "Clear all route points?",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear route", role: .destructive) {
                model.clear()
            }
            Button("Keep Points", role: .cancel) {}
        } message: {
            Text("Every drawn point will be removed. The route name and closed-loop setting are kept.")
        }
    }

    // MARK: - Map content

    /// Through `RouteGeometry` so a closed loop draws its closing segment; falls back to the raw
    /// taps while the draft is still too short to form a geometry.
    private var previewCoordinates: [CLLocationCoordinate2D] {
        let points = (try? RouteGeometry(points: model.points, isClosed: model.isClosed))?.points
            ?? model.points
        return points.map(\.clCoordinate)
    }

    // MARK: - Overlays

    private func nameField(text: Binding<String>) -> some View {
        TextField("Route name", text: text)
            .font(.headline)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
            .accessibilityLabel("Route name")
    }

    @ViewBuilder
    private func editorPanel(isClosed: Binding<Bool>) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: false) {
                    panelContent(isClosed: isClosed)
                }
                .frame(maxHeight: 460)
            } else {
                panelContent(isClosed: isClosed)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
    }

    private func panelContent(isClosed: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                metric(title: "Points", value: "\(model.effectivePointCount)")
                metric(title: "Distance", value: distanceText)
            }

            Toggle("Closed loop", isOn: isClosed)
                .accessibilityLabel("Closed loop")

            if let message = model.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            controls
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 10) {
            Button("Undo") {
                model.undoLastPoint()
            }
            .disabled(!model.canUndo)
            .accessibilityLabel("Undo last point")

            Button("Clear", role: .destructive) {
                isConfirmingClear = true
            }
            .disabled(model.points.isEmpty)
            .accessibilityLabel("Clear route")
        }

        HStack(spacing: 10) {
            Button("Cancel") {
                onCancel()
            }
            .accessibilityLabel("Cancel route editing")

            Spacer(minLength: 0)

            Button("Save") {
                save()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canSave)
            .accessibilityLabel("Save route")
        }
    }

    // MARK: - Actions

    /// `RouteEditorModel` writes the failure into `errorMessage`, which the panel shows, so a save
    /// that throws needs no second message source here.
    private func save() {
        do {
            onSave(try model.makeRoute(existing: existingRoute))
        } catch {
            return
        }
    }

    private var distanceText: String {
        let meters = model.totalDistance
        guard meters >= 1000 else {
            return String(format: "%.0f m", meters)
        }
        return String(format: "%.2f km", meters / 1000)
    }

    // MARK: - Camera

    /// Frames the existing route with 40% padding, never tighter than 0.002°; a new draft follows
    /// the user's location with the system fallback.
    private static func editingCamera(for route: RouteDefinition?) -> MapCameraPosition {
        let fallback = MapCameraPosition.userLocation(fallback: .automatic)
        guard let points = route?.points, points.count > 1 else {
            return fallback
        }

        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        guard let minimumLatitude = latitudes.min(), let maximumLatitude = latitudes.max(),
              let minimumLongitude = longitudes.min(), let maximumLongitude = longitudes.max() else {
            return fallback
        }

        let centre = CLLocationCoordinate2D(
            latitude: (minimumLatitude + maximumLatitude) / 2,
            longitude: (minimumLongitude + maximumLongitude) / 2
        )
        let padding = 1.4
        let minimumSpan = 0.002
        let span = MKCoordinateSpan(
            latitudeDelta: max((maximumLatitude - minimumLatitude) * padding, minimumSpan),
            longitudeDelta: max((maximumLongitude - minimumLongitude) * padding, minimumSpan)
        )
        return .region(MKCoordinateRegion(center: centre, span: span))
    }
}

private extension GeoCoordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
