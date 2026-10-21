import Foundation

/// One food estimate pasted from the Claude app (D-016). The app stays offline: the owner asks
/// Claude on the phone, copies its answer and pastes it here.
///
/// Format, one food per line: `EB1|name|kcal|protein|fat|carbs|servings`
/// Numbers are per serving; `servings` is optional (default 1) and is more than 1 for a container
/// meant for several meals. Decimal commas are accepted; text around the code is ignored.
public struct ClaudeFoodCode: Hashable, Sendable {
    public var title: String
    public var perServing: Nutrition
    public var servings: Int

    public init(title: String, perServing: Nutrition, servings: Int = 1) {
        self.title = title
        self.perServing = perServing
        self.servings = servings
    }

    public static let prefix = "EB1|"

    /// Every valid code found in `text`, in order. Malformed lines are skipped.
    public static func parseAll(_ text: String) -> [ClaudeFoodCode] {
        text.components(separatedBy: .newlines).compactMap(parseLine)
    }

    static func parseLine(_ line: String) -> ClaudeFoodCode? {
        guard let start = line.range(of: prefix) else { return nil }
        // Drop the prefix and any wrapping characters (backticks, quotes) after the code.
        let body = line[start.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: "`\"' \t"))
        let fields = body.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard fields.count >= 5 else { return nil }
        let title = fields[0]
        let numbers = fields[1...4].map { Double($0.replacingOccurrences(of: ",", with: ".")) }
        guard !title.isEmpty, numbers.allSatisfy({ ($0 ?? -1) >= 0 }) else { return nil }
        let servings = fields.count > 5 ? Int(fields[5]) ?? 1 : 1
        return ClaudeFoodCode(
            title: title,
            perServing: Nutrition(kcal: numbers[0]!, protein: numbers[1]!, fat: numbers[2]!, carbs: numbers[3]!),
            servings: min(max(servings, 1), 20)
        )
    }
}
