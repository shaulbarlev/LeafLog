import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: PlantStore

    var body: some View {
        TabView {
            NavigationStack {
                PlantListView()
            }
            .tabItem {
                Label("Plants", systemImage: "leaf")
            }

            NavigationStack {
                WateringCalendarView()
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let undoState = store.pendingUndo {
                UndoBar(
                    title: undoState.title,
                    subtitle: undoState.plantName,
                    onUndo: {
                        store.undoPendingAction()
                    },
                    onDismiss: {
                        store.clearPendingUndo()
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: store.pendingUndo?.id)
    }
}

private struct UndoBar: View {
    let title: String
    let subtitle: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Undo", action: onUndo)
                .buttonStyle(.borderedProminent)
                .tint(.green)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .padding(8)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }
}
