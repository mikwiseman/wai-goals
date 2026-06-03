import Foundation

enum AppTab: String, Hashable {
    case today, goals, stats
}

/// Parses launch arguments used for development, screenshots, and (later) deep
/// links. Real users never pass these, so behavior is unaffected in normal use.
enum AppLaunch {
    private static var args: [String] { CommandLine.arguments }

    static var seedSampleData: Bool { args.contains("-seedSampleData") }

    static var initialTab: AppTab {
        value(for: "-tab").flatMap(AppTab.init(rawValue:)) ?? .today
    }

    /// "editor", "settings", or "detail".
    static var openTarget: String? { value(for: "-open") }

    private static func value(for flag: String) -> String? {
        guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }
}
