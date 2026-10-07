import AppKit
import NotelyCore

/// A tint as saved in `Note.tint`: sRGB "#RRGGBB". Alpha is dropped, so
/// no color can make a note's tint stronger than `tintStrength`.
func tintString(_ color: NSColor) -> String? {
    guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
    let channel = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
    return TintRGB(red: channel(rgb.redComponent), green: channel(rgb.greenComponent),
                   blue: channel(rgb.blueComponent)).hex
}

/// The color of a saved tint, or nil when nothing usable is saved.
func tintColor(_ saved: String?) -> NSColor? {
    guard let rgb = TintRGB(hex: saved) else { return nil }
    return NSColor(srgbRed: CGFloat(rgb.red) / 255,
                   green: CGFloat(rgb.green) / 255,
                   blue: CGFloat(rgb.blue) / 255,
                   alpha: 1)
}

/// The tint menu's preset colors, in menu order. Fixed values, not system
/// colors: system colors change with the appearance, so a saved preset
/// would stop matching its menu entry.
let tintPresets: [(name: String, tint: String)] = [
    ("Yellow", "#FFD60A"),
    ("Orange", "#FF9F0A"),
    ("Pink", "#FF375F"),
    ("Purple", "#BF5AF2"),
    ("Blue", "#0A84FF"),
    ("Green", "#30D158"),
    ("Gray", "#8E8E93"),
]
