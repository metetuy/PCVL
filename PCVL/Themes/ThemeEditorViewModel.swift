import SwiftUI
import Combine

// MARK: - Theme Editor View Model

/// Draft of a custom theme being created or edited. Independent of where it is
/// shown, so the window's editor and a future panel editor share it.
@MainActor
final class ThemeEditorViewModel: ObservableObject, Identifiable {
    let id = UUID()

    @Published var name: String
    @Published var palette: ThemePalette
    @Published var selectedRole: ThemeColorRole = .accent

    /// The custom theme being edited; nil while creating a new one.
    let editingID: UUID?
    private let themeManager: ThemeManager
    /// The draft as it was opened, for `revert()`.
    private let originalName: String
    private let originalPalette: ThemePalette

    /// A new theme, starting from the current theme's colors.
    convenience init(themeManager: ThemeManager) {
        self.init(
            themeManager: themeManager,
            editingID: nil,
            name: Self.suggestedName(in: themeManager),
            palette: ThemePalette(themeManager.colors)
        )
    }

    convenience init(themeManager: ThemeManager, editing theme: CustomTheme) {
        self.init(themeManager: themeManager, editingID: theme.id, name: theme.name, palette: theme.palette)
    }

    private init(themeManager: ThemeManager, editingID: UUID?, name: String, palette: ThemePalette) {
        self.themeManager = themeManager
        self.editingID = editingID
        self.name = name
        self.palette = palette
        originalName = name
        originalPalette = palette
    }

    var isEditing: Bool { editingID != nil }

    /// Whether the name or any color differs from when the draft was opened. Colors
    /// compare by hex: that is what gets saved.
    var hasChanges: Bool {
        name != originalName || ThemeColorRole.allCases.contains { palette[$0].hex != originalPalette[$0].hex }
    }

    var selectedColor: RGBColor {
        get { palette[selectedRole] }
        set { palette[selectedRole] = newValue }
    }

    /// Everything that blocks saving, worded for display.
    var problems: [String] {
        let name = trimmedName
        var problems: [String] = []
        if name.isEmpty {
            problems.append("Give the theme a name.")
        } else if themeManager.isThemeNameTaken(name, excluding: editingID) {
            problems.append("A theme named “\(name)” already exists.")
        }
        return problems + palette.problems
    }

    var canSave: Bool { problems.isEmpty }

    /// Replaces every color with another theme's (the name is kept).
    func start(from option: ThemeOption) {
        palette = ThemePalette(option.colors)
    }

    /// Back to the name and colors the draft was opened with (the selected color stays).
    func revert() {
        name = originalName
        palette = originalPalette
    }

    /// Saves the theme and makes it the current one.
    func save() {
        guard canSave else { return }
        let theme = CustomTheme(id: editingID ?? UUID(), name: trimmedName, palette: palette)
        themeManager.saveCustomTheme(theme)
        themeManager.currentTheme = .custom(theme.id)
    }

    func delete() {
        guard let editingID else { return }
        themeManager.deleteCustomTheme(editingID)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func suggestedName(in themeManager: ThemeManager) -> String {
        let base = "My Theme"
        var name = base
        var number = 2
        while themeManager.isThemeNameTaken(name) {
            name = "\(base) \(number)"
            number += 1
        }
        return name
    }

    // MARK: - Swatches

    /// Typical colors offered next to the spectrum: neutrals, vivid hues, then
    /// muted darks and pastels that suit backgrounds and surfaces.
    static let swatches: [RGBColor] = [
        "#FFFFFF", "#E5E5EA", "#AEAEB2", "#8E8E93", "#636366", "#3A3A3C", "#1C1C1E", "#000000",
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#007AFF", "#5856D6", "#AF52DE",
        "#0D1B2A", "#141418", "#241A28", "#1B4332", "#F7F7FB", "#FFE5EC", "#FAF0CA", "#CAE9FF",
    ].compactMap(RGBColor.init(hex:))
}
