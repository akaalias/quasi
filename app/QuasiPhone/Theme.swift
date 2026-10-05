import SwiftUI
import UIKit

/// The Logbook look: warm paper, dark ink, and one burnt orange that only ever means
/// "the app did something". What you said is set in a serif; what the app says is not.
///
/// The sizes come from the design's mock-ups (design/directions), measured on a 402-point-wide
/// screen; `tools/overlay.py` lays a screenshot over the mock-up to check them.
extension Color {
    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }

    static let paper = dynamic(0xFBF8F2, 0x161411)
    static let sheetPaper = dynamic(0xFFFDF9, 0x1E1B17)
    static let ink = dynamic(0x1E1B16, 0xEDE6DA)
    static let quiet = dynamic(0x8A8173, 0x9A9080)
    static let card = dynamic(0xF1EBDF, 0x26221D)
    static let chip = dynamic(0xEDE5D6, 0x322D26)
    static let rule = dynamic(0xDDD3C1, 0x3A342C)
    static let brand = dynamic(0xC8551F, 0xEF8249)
    static let mark = dynamic(0xF6D9B8, 0x5D381C)
}

/// A text style as the mock-ups define one: a size, a weight, serif or not, and a line height
/// given as a multiple of the size, laid out the way CSS does (the extra space split above and below).
struct Typo {
    var size: CGFloat
    var weight: UIFont.Weight = .regular
    var serif = false
    var line: CGFloat = 1.35
    /// The mock-ups set the small sans a little looser than iOS does by default.
    var tracking: CGFloat = 0

    static let ui = Typo(size: 17.7, tracking: 0.6)
    static let uiStrong = Typo(size: 17.7, weight: .semibold, tracking: 0)
    static let small = Typo(size: 15.6, weight: .semibold, tracking: 0.6)
    static let section = Typo(size: 14, weight: .semibold, tracking: 1.6)
    static let quote = Typo(size: 22.6, serif: true)
    static let transcript = Typo(size: 22.7, serif: true, line: 1.471)
    static let live = Typo(size: 23.1, serif: true, line: 1.4)
    static let day = Typo(size: 40.3, serif: true, line: 1.1)
    static let earlierDay = Typo(size: 29.5, serif: true, line: 1.1)
    static let cardTitle = Typo(size: 19.9, weight: .semibold, tracking: 0.45)
    static let screenTitle = Typo(size: 21.5, weight: .bold, tracking: 0.5)

    var uiFont: UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard serif, let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

extension View {
    func typo(_ style: Typo) -> some View {
        let font = style.uiFont
        // A line box shorter than the font's own (large titles) is cut by a negative inset.
        let extra = style.size * style.line - font.lineHeight
        return self.font(Font(font)).tracking(style.tracking).lineSpacing(max(0, extra)).padding(.vertical, extra / 2)
    }
}

/// Measures from the mock-ups, in points.
enum Metric {
    static let margin: CGFloat = 27.4
    static let gap: CGFloat = 15.2
    static let radius: CGFloat = 22.8
}

/// The hairline between entries and rows.
struct Rule: View {
    var body: some View { Rectangle().fill(Color.rule).frame(height: 1) }
}

/// A pill button as in the mock-ups: quiet by default.
struct PillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .typo(.small)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 19.8)
            .padding(.vertical, 3.2)
            .background(Color.chip, in: Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// The switch from the mock-ups.
struct SwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Capsule().fill(configuration.isOn ? Color.brand : Color.rule)
                .frame(width: 48.7, height: 28.9)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(.white).frame(width: 22.8, height: 22.8).padding(3)
                }
                .animation(.easeOut(duration: 0.15), value: configuration.isOn)
                .onTapGesture { configuration.isOn.toggle() }
        }
    }
}
