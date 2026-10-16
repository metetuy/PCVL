import SwiftUI

// MARK: - Theme Editor Screen

/// Create or edit a custom theme, shown in place of the settings screen: the panel
/// previewed live with the draft palette and its colors on the left, the name and
/// the picker for the selected color on the right.
struct ThemeEditorScreen: View {
    @ObservedObject var model: ThemeEditorViewModel
    @ObservedObject var theme: ThemeManager
    let onClose: () -> Void

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
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(theme.currentFont.font(size: 13, weight: .semibold))
                    .foregroundColor(theme.colors.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverEffect()
            .help("Back to Settings")

            Text(model.isEditing ? "Edit Theme" : "New Theme")
                .font(theme.currentFont.font(size: 20, weight: .semibold))
                .foregroundColor(theme.colors.text)

            Spacer()

            Menu {
                ForEach(theme.themeOptions) { option in
                    Button(option.name) { model.start(from: option) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text("Start from")
                        .font(theme.currentFont.font(size: 12, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(theme.currentFont.font(size: 9, weight: .semibold))
                }
                .foregroundColor(theme.colors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .cardBackground(theme, radius: 7)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .hoverEffect()
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

    private var footer: some View {
        HStack(spacing: 10) {
            if model.isEditing {
                footerButton("Delete", color: Color(nsColor: NSColor(red: 0.85, green: 0.3, blue: 0.3, alpha: 1))) {
                    model.delete()
                    onClose()
                }
            }

            footerButton("Revert", color: theme.colors.textSecondary, action: model.revert)
                .disabled(!model.hasChanges)
                .opacity(model.hasChanges ? 1 : 0.4)
                .help(model.isEditing ? "Undo changes since this theme was opened" : "Back to the colors this theme started with")

            Spacer()

            if let problem = model.problems.first {
                Text(problem)
                    .font(theme.currentFont.font(size: 11))
                    .foregroundColor(theme.colors.textSecondary)
                    .lineLimit(1)
            }

            footerButton("Cancel", color: theme.colors.textSecondary, action: onClose)
                .keyboardShortcut(.cancelAction)

            footerButton("Save", color: theme.colors.accent) {
                model.save()
                onClose()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!model.canSave)
            .opacity(model.canSave ? 1 : 0.4)
        }
    }

    private func footerButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(theme.currentFont.font(size: 12, weight: .medium))
                .foregroundColor(color)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
}
