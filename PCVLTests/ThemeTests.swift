import Foundation
import Testing
@testable import PCVL

/// Custom themes: color math, palette rules, persistence and the editor, against
/// throwaway defaults.
@MainActor
struct ThemeTests {
    private let defaults: UserDefaults

    init() {
        let suite = "PCVLTests.Themes.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    private var samplePalette: ThemePalette {
        ThemePalette(ThemeManager.colors(for: .dark))
    }

    // MARK: - Colors

    @Test func parsesHex() throws {
        let color = try #require(RGBColor(hex: "#F29640"))
        #expect(color.hex == "#F29640")
        #expect(RGBColor(hex: "f29640")?.hex == "#F29640")
        #expect(RGBColor(hex: " #fa0 ")?.hex == "#FFAA00", "short form expands")
        #expect(RGBColor(hex: "#12345") == nil)
        #expect(RGBColor(hex: "#GG0000") == nil)
        #expect(RGBColor(hex: "+12345") == nil)
    }

    @Test func hsbRoundTrips() throws {
        for hex in ["#F29640", "#0A1429", "#40B3D9", "#808080", "#000000", "#FFFFFF", "#FF0000"] {
            let color = try #require(RGBColor(hex: hex))
            let hsb = color.hsb
            #expect(RGBColor(hue: hsb.hue, saturation: hsb.saturation, brightness: hsb.brightness).hex == hex)
        }
        #expect(RGBColor(hue: 1, saturation: 1, brightness: 1).hex == "#FF0000", "hue wraps")
    }

    @Test func paletteEncodesAsHex() throws {
        let data = try JSONEncoder().encode(samplePalette)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"accent\":\"\(samplePalette.accent.hex)\""))
        let decoded = try JSONDecoder().decode(ThemePalette.self, from: data)
        for role in ThemeColorRole.allCases {
            #expect(decoded[role].hex == samplePalette[role].hex)
        }
    }

    @Test func paletteRules() {
        var palette = samplePalette
        #expect(palette.problems.isEmpty)
        palette.ringTrack = palette.surface
        palette.accent = palette.textSecondary
        #expect(palette.problems.count == 2)
    }

    // MARK: - Theme Manager

    @Test func legacySelectionStillLoads() {
        defaults.set("Ocean", forKey: "selectedTheme")
        #expect(ThemeManager(defaults: defaults).currentTheme == .builtIn(.ocean))
    }

    @Test func customThemePersistsAndApplies() {
        let manager = ThemeManager(defaults: defaults)
        let custom = CustomTheme(name: "Mine", palette: samplePalette)
        manager.saveCustomTheme(custom)
        manager.currentTheme = .custom(custom.id)
        #expect(RGBColor(manager.colors.accent).hex == samplePalette.accent.hex)

        let reloaded = ThemeManager(defaults: defaults)
        #expect(reloaded.currentTheme == .custom(custom.id))
        #expect(reloaded.currentThemeName == "Mine")
        #expect(reloaded.themeOptions.last?.name == "Mine")
        #expect(reloaded.themeOptions.count == AppTheme.allCases.count + 1)
    }

    @Test func editingCurrentThemeUpdatesColors() {
        let manager = ThemeManager(defaults: defaults)
        var custom = CustomTheme(name: "Mine", palette: samplePalette)
        manager.saveCustomTheme(custom)
        manager.currentTheme = .custom(custom.id)

        custom.palette.accent = RGBColor(hex: "#00FF00")!
        manager.saveCustomTheme(custom)
        #expect(manager.customThemes.count == 1, "saving the same id replaces")
        #expect(RGBColor(manager.colors.accent).hex == "#00FF00")
    }

    @Test func deletingCurrentThemeFallsBack() {
        let manager = ThemeManager(defaults: defaults)
        let custom = CustomTheme(name: "Mine", palette: samplePalette)
        manager.saveCustomTheme(custom)
        manager.currentTheme = .custom(custom.id)

        manager.deleteCustomTheme(custom.id)
        #expect(manager.currentTheme == .builtIn(.minimalist))
        #expect(manager.customThemes.isEmpty)
        #expect(ThemeManager(defaults: defaults).currentTheme == .builtIn(.minimalist))
    }

    // MARK: - Editor

    @Test func editorValidatesAndSaves() {
        let manager = ThemeManager(defaults: defaults)
        let editor = ThemeEditorViewModel(themeManager: manager)
        #expect(editor.name == "My Theme")

        editor.start(from: manager.themeOptions.first { $0.selection == .builtIn(.dark) }!)
        editor.name = "dark"
        #expect(!editor.canSave, "names are unique, ignoring case")
        editor.name = "  "
        #expect(!editor.canSave)
        editor.name = " Sunset "

        editor.selectedRole = .accent
        editor.selectedColor = RGBColor(hex: "#FF5500")!
        #expect(editor.palette.accent.hex == "#FF5500")

        editor.save()
        let saved = manager.customThemes.first
        #expect(saved?.name == "Sunset")
        #expect(manager.currentTheme == .custom(saved!.id), "saving applies the theme")
        #expect(ThemeEditorViewModel(themeManager: manager).name == "My Theme", "suggested name skips taken ones only")
    }

    @Test func editorEditsInPlace() {
        let manager = ThemeManager(defaults: defaults)
        let custom = CustomTheme(name: "Mine", palette: samplePalette)
        manager.saveCustomTheme(custom)

        let editor = ThemeEditorViewModel(themeManager: manager, editing: custom)
        #expect(editor.canSave, "its own name is not taken")
        editor.name = "Renamed"
        editor.save()
        #expect(manager.customThemes.map(\.name) == ["Renamed"])

        editor.delete()
        #expect(manager.customThemes.isEmpty)
    }
}
