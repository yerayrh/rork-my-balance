import SwiftUI

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: Double
        if s.count == 6 {
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
        } else {
            r = 0.5; g = 0.5; b = 0.5
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// "#RRGGBB" in sRGB (alpha ignored).
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }
}

enum HexColor {
    static func luminance(_ hex: String) -> Double {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    static func prefersDarkText(_ hex: String) -> Bool { luminance(hex) > 0.68 }

    static let swatches: [String] = [
        "#2F5BFF", "#0EA5E9", "#14B8A6", "#19C37D", "#84CC16", "#F59E0B",
        "#FF7A2F", "#EF4444", "#FF5C8A", "#EC4899", "#A855F7", "#7C5CFF",
        "#6366F1", "#0F766E", "#B45309", "#64748B", "#111827", "#94A3B8",
    ]
}

struct AppTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let accentLight: String
    let accentDark: String
    let secondary: String
    let surfaceLight: String
    let surfaceDark: String

    static let all: [AppTheme] = [
        AppTheme(id: "electric", name: "Azul eléctrico", accentLight: "#2F5BFF", accentDark: "#5B7CFF", secondary: "#FF5C8A", surfaceLight: "#F2F5FF", surfaceDark: "#13151D"),
        AppTheme(id: "lime", name: "Lima neón", accentLight: "#4D7C0F", accentDark: "#C6F432", secondary: "#FF6B5A", surfaceLight: "#F3F8E6", surfaceDark: "#14170F"),
        AppTheme(id: "sunset", name: "Atardecer", accentLight: "#F2620F", accentDark: "#FF8A47", secondary: "#8B5CF6", surfaceLight: "#FFF4EA", surfaceDark: "#1B1410"),
        AppTheme(id: "forest", name: "Bosque", accentLight: "#15803D", accentDark: "#3DDC84", secondary: "#F59E0B", surfaceLight: "#EEF6F0", surfaceDark: "#0F1712"),
        AppTheme(id: "lavender", name: "Lavanda", accentLight: "#7C5CFF", accentDark: "#A792FF", secondary: "#14B8A6", surfaceLight: "#F4F1FF", surfaceDark: "#16131F"),
        AppTheme(id: "coral", name: "Coral", accentLight: "#F0457A", accentDark: "#FF6F97", secondary: "#2F5BFF", surfaceLight: "#FFF0F4", surfaceDark: "#1D1216"),
        AppTheme(id: "ocean", name: "Océano", accentLight: "#0284C7", accentDark: "#22D3EE", secondary: "#F97316", surfaceLight: "#EBF7FD", surfaceDark: "#0D171B"),
        AppTheme(id: "gold", name: "Oro", accentLight: "#A16207", accentDark: "#F5C451", secondary: "#6366F1", surfaceLight: "#FBF5E7", surfaceDark: "#18150D"),
        AppTheme(id: "cherry", name: "Cereza", accentLight: "#E11D48", accentDark: "#FB7185", secondary: "#0EA5E9", surfaceLight: "#FFF1F3", surfaceDark: "#1C1013"),
        AppTheme(id: "mono", name: "Monocromo", accentLight: "#111111", accentDark: "#F5F5F5", secondary: "#8E8E93", surfaceLight: "#F3F3F4", surfaceDark: "#161618"),
    ]

    static func find(_ id: String) -> AppTheme { all.first { $0.id == id } ?? all[0] }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light, dark
    var id: String { rawValue }
    var label: String { self == .light ? "Claro" : "Oscuro" }
    var colorScheme: ColorScheme { self == .light ? .light : .dark }
}

struct Palette {
    var accent: Color
    var secondary: Color
    var surface: Color
    var canvas: Color
    var onAccent: Color
    var isDark: Bool
    var positive: Color = Color(hex: "#19C37D")
    var negative: Color = Color(hex: "#FF4D6D")

    static func make(theme: AppTheme, dark: Bool) -> Palette {
        let accentHex = dark ? theme.accentDark : theme.accentLight
        return Palette(
            accent: Color(hex: accentHex),
            secondary: Color(hex: theme.secondary),
            surface: Color(hex: dark ? theme.surfaceDark : theme.surfaceLight),
            canvas: dark ? Color(hex: "#08090C") : .white,
            onAccent: HexColor.prefersDarkText(accentHex) ? .black : .white,
            isDark: dark
        )
    }
}

extension EnvironmentValues {
    @Entry var palette: Palette = Palette.make(theme: AppTheme.all[0], dark: false)
}
