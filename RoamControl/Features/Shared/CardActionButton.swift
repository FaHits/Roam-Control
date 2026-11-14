import SwiftUI

/// The three roles a card action can take. Cards route every button through `CardActionButton`,
/// so the same action cannot come out as a filled capsule on one card and a bordered square on
/// another — the mismatch the Run Card and the location card had for "Stop & Restore".
enum CardActionKind {
    case primary
    case destructive
    case secondary
}

/// One card action drawn one way. The style rules live here and nowhere else: a call site picks a
/// `kind` and never adds its own `buttonStyle`, `controlSize` or `tint`.
struct CardActionButton: View {
    let kind: CardActionKind
    let title: LocalizedStringKey
    let symbol: String
    /// The compact form drops the title and keeps a 28 pt icon column, for the icon-only buttons
    /// that share a row with a wide one.
    var showsTitle: Bool = true
    /// A busy action swaps its symbol for a spinner without changing the frame.
    var isWorking: Bool = false
    /// Only for buttons whose spoken name differs from their title, such as "Stop & Restore" being
    /// announced as "Stop".
    var accessibilityLabel: Text? = nil
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        identifiedButton
            .accessibilityLabel(accessibilityLabel ?? Text(title))
    }

    @ViewBuilder
    private var identifiedButton: some View {
        if let identifier = accessibilityIdentifier {
            styledButton.accessibilityIdentifier(identifier)
        } else {
            styledButton
        }
    }

    @ViewBuilder
    private var styledButton: some View {
        switch kind {
        case .primary:
            baseButton.buttonStyle(.borderedProminent)
        case .destructive:
            baseButton.buttonStyle(.borderedProminent).tint(.red)
        case .secondary:
            baseButton.buttonStyle(.bordered)
        }
    }

    private var baseButton: some View {
        Button(action: action) {
            label
        }
        .controlSize(.large)
    }

    @ViewBuilder
    private var label: some View {
        if showsTitle {
            Label {
                Text(title)
            } icon: {
                icon
            }
            .frame(maxWidth: .infinity, minHeight: 46)
        } else {
            icon
                .frame(width: 28)
                .frame(minHeight: 46)
        }
    }

    /// A spinner on a filled button has to be white to stay visible; on a bordered one the default
    /// tint already reads, and the small size keeps it inside the stroke.
    @ViewBuilder
    private var icon: some View {
        if !isWorking {
            Image(systemName: symbol)
        } else if kind == .secondary {
            ProgressView()
                .controlSize(.small)
        } else {
            ProgressView()
                .tint(.white)
        }
    }
}

extension View {
    /// The borderless tap target a card's inline icons use — copy, favourite, clear. Those are not
    /// card actions and must not grow a border, but the card still should not name a button style
    /// itself, so the one place that can is this file.
    func cardIconButtonStyle() -> some View {
        buttonStyle(.plain)
    }
}
