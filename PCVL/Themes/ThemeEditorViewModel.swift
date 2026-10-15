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

    /// A new theme, starting from the current theme's colors.
    init(themeManager: ThemeManager) {
        self.themeManager = themeManager
        editingID = nil
        palette = ThemePalette(themeManager.colors)
        name = Self.suggestedName(in: themeManager)
    }

    init(themeManager: ThemeManager, editing theme: CustomTheme) {
        self.themeManager = themeManager
        editingID = theme.id
        palette = theme.palette
        name = theme.name
    }

    var isEditing: Bool { editingID != nil }

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
