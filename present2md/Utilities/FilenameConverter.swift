import Foundation

public enum FilenameConverter {
    public static func convert(_ filename: String) -> String {
        var name = (filename as NSString).deletingPathExtension
        name = name.lowercased()
        // Replace whitespace, hyphens, en-dash, em-dash, and dots with underscore
        let separators = CharacterSet(charactersIn: " \t\u{2013}\u{2014}-.")
        name = name.components(separatedBy: separators).joined(separator: "_")
        // Strip any character that is not a unicode letter, digit, or underscore
        name = name.unicodeScalars.filter { scalar in
            CharacterSet.letters.union(.decimalDigits)
                .union(CharacterSet(charactersIn: "_"))
                .contains(scalar)
        }.map { String($0) }.joined()
        // Collapse consecutive underscores
        while name.contains("__") {
            name = name.replacingOccurrences(of: "__", with: "_")
        }
        // Trim leading/trailing underscores
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if name.isEmpty { name = "_" }
        // Truncate stem to 200 chars
        if name.count > 200 { name = String(name.prefix(200)) }
        return name + ".md"
    }
}
