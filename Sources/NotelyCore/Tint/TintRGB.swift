import Foundation

/// A tint as saved in `Note.tint`: sRGB "#RRGGBB", one 0-255 value per
/// channel. Alpha is never saved.
public struct TintRGB: Equatable {
    public var red: Int
    public var green: Int
    public var blue: Int

    public init(red: Int, green: Int, blue: Int) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// The channels of a saved tint, or nil when nothing usable is saved.
    public init?(hex saved: String?) {
        guard let saved, saved.count == 7, saved.first == "#",
              saved.dropFirst().allSatisfy(\.isHexDigit),
              let value = UInt32(saved.dropFirst(), radix: 16) else { return nil }
        red = Int((value >> 16) & 0xFF)
        green = Int((value >> 8) & 0xFF)
        blue = Int(value & 0xFF)
    }

    /// The tint as saved: "#RRGGBB" in uppercase hex.
    public var hex: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }
}
