import SwiftUI

// MARK: - Theme Editor Screen

/// Create or edit a custom theme, shown in place of the settings screen: the panel
/// previewed live with the draft palette and its colors on the left, the name and
/// the picker for the selected color on the right.
struct ThemeEditorScreen: View {
    @ObservedObject var model: ThemeEditorViewModel
    @ObservedObject var theme: ThemeManager
    let onClose: () -> Void

    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var isConfirmingDelete = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 16) {
                        ThemePreview(colors: model.palette.colors, theme: theme, isBreak: model.selectedRole == .breakRing)
                        ThemeRoleList(palette: model.palette, selection: $model.selectedRole, theme: theme)
                            .padding(4)
                            .cardBackground(theme, radius: 10)
                    }
                    .frame(width: ThemePreview.size.width)

                    VStack(alignment: .leading, spacing: 16) {
                        nameField
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.selectedRole.title)
                                    .font(theme.currentFont.font(size: 13, weight: .semibold))
                                    .foregroundColor(theme.colors.text)
                                Text(model.selectedRole.detail)
                                    .font(theme.currentFont.font(size: 11))
                                    .foregroundColor(theme.colors.textSecondary)
                            }
                            ThemeColorPicker(color: $model.selectedColor, swatches: ThemeEditorViewModel.swatches, theme: theme)
                        }
                        .padding(14)
                        .cardBackground(theme, radius: 10)
                    }
                    .frame(maxWidth: .infinity)
                }

                footer
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // Native controls (buttons, text fields, menus) drawn light or dark to suit
        // the theme rather than the system appearance.
        .environment(\.colorScheme, theme.colorScheme ?? systemColorScheme)
        .controlSize(.large)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
            }
            .buttonBorderShape(.circle)
            .help("Back to Settings")

            Text(model.isEditing ? "Edit Theme" : "New Theme")
                .font(theme.currentFont.font(size: 20, weight: .semibold))
                .foregroundColor(theme.colors.text)

            Spacer()

            Menu("Start From") {
                ForEach(theme.themeOptions) { option in
                    Button(option.name) { model.start(from: option) }
                }
            }
            .fixedSize()
            .help("Replace every color with another theme's")
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Name", theme: theme, scale: 1.2)
            TextField("Theme name", text: $model.name)
                .textFieldStyle(.plain)
                .font(theme.currentFont.font(size: 13, weight: .medium))
                .foregroundColor(theme.colors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .cardBackground(theme, radius: 8)
        }
    }

    // MARK: - Footer

    /// Laid out like a macOS dialog: actions on the draft itself (Delete, Revert) on
    /// the left, Cancel and the prominent Save on the right.
    private var footer: some View {
        HStack(spacing: 10) {
            if model.isEditing {
                deleteButton
            }

            Button("Revert", action: model.revert)
                .disabled(!model.hasChanges)
                .help(model.isEditing ? "Undo changes since this theme was opened" : "Back to the colors this theme started with")

            Spacer(minLength: 12)

            if let problem = model.problems.first {
                Text(problem)
                    .font(theme.currentFont.font(size: 11))
                    .foregroundColor(theme.colors.textSecondary)
                    .lineLimit(1)
            }

            Button("Cancel", action: onClose)
                .keyboardShortcut(.cancelAction)

            Button {
                model.save()
                onClose()
            } label: {
                Text("Save")
                    // The theme's own pairing on its accent, as on the timer's start
                    // button; inactive windows draw the button grey, so the system
                    // label color takes over there.
                    .foregroundStyle(controlActiveState == .inactive ? AnyShapeStyle(.primary) : AnyShapeStyle(theme.colors.background))
                    .frame(minWidth: 56)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.colors.accent)
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!model.canSave)
            .help("Save and apply (⌘S)")
        }
    }

    /// Two steps: Delete collapses into a trash circle on a red "Are you sure?" bar,
    /// and only the circle deletes, so a double click never does. It stays that way
    /// until the next click: anywhere but the circle puts Delete back.
    private var deleteButton: some View {
        HStack(spacing: 0) {
            if isConfirmingDelete {
                HStack(spacing: 0) {
                    Button {
                        model.delete()
                        onClose()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red)
                            .frame(width: Self.deleteHeight - 4, height: Self.deleteHeight - 4)
                            .background(.white, in: Circle())
                            .contentShape(Circle())
                            // Inset, so a red ring keeps it apart from light backgrounds.
                            .padding(2)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .help("Delete this theme")

                    Text("Are you sure?")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .padding(.leading, 8)
                        .padding(.trailing, 14)
                }
                .frame(height: Self.deleteHeight)
                .background(.red, in: Capsule())
            } else {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Delete")
                        Image(systemName: "trash")
                    }
                    .foregroundStyle(.red)
                }
                .help("Delete this theme")
            }
        }
        .disarmOnNextClick($isConfirmingDelete)
    }

    /// Height of a large native button, so the confirmation lines up with its row.
    private static let deleteHeight: CGFloat = 28
}

// MARK: - Disarm on Next Click

private extension View {
    /// Sets `isArmed` back to false after the next mouse click anywhere in the app.
    func disarmOnNextClick(_ isArmed: Binding<Bool>) -> some View {
        modifier(DisarmOnNextClick(isArmed: isArmed))
    }
}

/// Watches clicks only while armed. Installed after the arming click has been
/// handled, so that click never counts; disarms after the next click has been
/// handled, so a click on the confirming button still lands.
private struct DisarmOnNextClick: ViewModifier {
    @Binding var isArmed: Bool
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onChange(of: isArmed) { _, armed in
                armed ? install() : remove()
            }
            .onDisappear(perform: remove)
    }

    private func install() {
        remove()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp, .otherMouseUp]) { event in
            DispatchQueue.main.async { isArmed = false }
            return event
        }
    }

    private func remove() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
