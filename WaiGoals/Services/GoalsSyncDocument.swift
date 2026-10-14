import Foundation

enum GoalsSyncValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), array([GoalsSyncValue]), object([String: GoalsSyncValue]), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode([GoalsSyncValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: GoalsSyncValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    var text: String {
        switch self {
        case .string(let value): value
        case .number(let value): String(value)
        case .bool(let value): value ? "Yes" : "No"
        case .null: "—"
        case .array(let values): values.map(\.text).joined(separator: ", ")
        case .object: "Record"
        }
    }
}
typealias GoalsSyncRecord = [String: GoalsSyncValue]
enum GoalsSyncKind: String, Codable, CaseIterable, Sendable { case goals, completions, intentions, journal, achievements }
struct GoalsSyncChange: Codable, Equatable, Sendable {
    var kind: GoalsSyncKind; var id: String; var before: GoalsSyncRecord?; var after: GoalsSyncRecord?; var restore = false
    enum CodingKeys: String, CodingKey { case kind, id, before, after, restore }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind); try c.encode(id, forKey: .id)
        try c.encode(before, forKey: .before); try c.encode(after, forKey: .after)
        if restore { try c.encode(true, forKey: .restore) }
    }
    init(kind: GoalsSyncKind, id: String, before: GoalsSyncRecord?, after: GoalsSyncRecord?, restore: Bool = false) {
        self.kind = kind; self.id = id; self.before = before; self.after = after; self.restore = restore
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(GoalsSyncKind.self, forKey: .kind); id = try c.decode(String.self, forKey: .id)
        before = try c.decodeIfPresent(GoalsSyncRecord.self, forKey: .before); after = try c.decodeIfPresent(GoalsSyncRecord.self, forKey: .after)
        restore = try c.decodeIfPresent(Bool.self, forKey: .restore) ?? false
    }
}
struct GoalsSyncConflict: Error, LocalizedError, Identifiable {
    struct Entry: Identifiable {
        var kind: GoalsSyncKind; var recordID: String; var fields: [String]
        var local: GoalsSyncRecord?; var remote: GoalsSyncRecord?
        var id: String { kind.rawValue + ":" + recordID }
        var title: String { local?["title"]?.text ?? remote?["title"]?.text ?? local?["text"]?.text ?? kind.rawValue }
    }
    let id = UUID()
    var entries: [Entry]
    var errorDescription: String? { "Some changes conflict. Both versions are kept until you choose." }
}

struct GoalsSyncDocument: Codable, Equatable, Sendable {
    private var records: [GoalsSyncKind: [String: GoalsSyncRecord]] = [:]
    var deleted: [String: GoalsSyncValue] = [:]
    init() {}
    subscript(kind: GoalsSyncKind) -> [String: GoalsSyncRecord] {
        get { records[kind] ?? [:] }
        set { records[kind] = newValue }
    }
    private enum Keys: String, CodingKey { case goals, completions, intentions, journal, achievements, deleted }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        for kind in GoalsSyncKind.allCases { self[kind] = try c.decode([String: GoalsSyncRecord].self, forKey: Keys(rawValue: kind.rawValue)!) }
        deleted = try c.decodeIfPresent([String: GoalsSyncValue].self, forKey: .deleted) ?? [:]
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        for kind in GoalsSyncKind.allCases { try c.encode(self[kind], forKey: Keys(rawValue: kind.rawValue)!) }
        try c.encode(deleted, forKey: .deleted)
    }
    static func == (lhs: Self, rhs: Self) -> Bool {
        GoalsSyncKind.allCases.allSatisfy { lhs[$0] == rhs[$0] } && lhs.deleted == rhs.deleted
    }
    func tombstone(_ kind: GoalsSyncKind, _ id: String) -> GoalsSyncRecord? {
        guard case .object(let value) = deleted[kind.rawValue + ":" + id], case .object(let record) = value["record"] else { return nil }
        return record
    }
    func changes(since baseline: Self) -> [GoalsSyncChange] {
        GoalsSyncKind.allCases.flatMap { kind in
            Set(self[kind].keys).union(baseline[kind].keys).sorted().compactMap { id in
                let before = baseline[kind][id], after = self[kind][id]
                guard before != after else { return nil }
                let removed = before == nil ? baseline.tombstone(kind, id) : nil
                return GoalsSyncChange(kind: kind, id: id, before: before ?? removed, after: after, restore: removed != nil && after != nil)
            }
        }
    }
    static func merge(base: Self, local: Self, remote: Self, preferLocal: Bool? = nil) throws -> Self {
        var result = remote
        var conflicts: [GoalsSyncConflict.Entry] = []
        for kind in GoalsSyncKind.allCases {
            let ids = Set(base[kind].keys).union(local[kind].keys).union(remote[kind].keys)
            for id in ids.sorted() {
                let b = base[kind][id], l = local[kind][id], r = remote[kind][id]
                if l == b || l == r { continue }
                if kind == .achievements, let l, let r {
                    result[kind][id] = (l["unlockedAt"]?.text ?? "") < (r["unlockedAt"]?.text ?? "") ? l : r
                    continue
                }
                if r == b && !(b == nil && remote.tombstone(kind, id) != nil) { result[kind][id] = l; continue }
                guard let l, let r, let b else {
                    conflicts.append(.init(kind: kind, recordID: id, fields: ["record"], local: l, remote: r))
                    if preferLocal == true { result[kind][id] = l }
                    continue
                }
                var merged = r, fields: [String] = []
                for field in Set(l.keys).union(b.keys).sorted() where l[field] != b[field] {
                    if kind == .journal && field == "updatedAt" {
                        merged[field] = (l[field]?.text ?? "") > (r[field]?.text ?? "") ? l[field] : r[field]
                        continue
                    }
                    if r[field] == b[field] || r[field] == l[field] { merged[field] = l[field] }
                    else { fields.append(field); if preferLocal == true { merged[field] = l[field] } }
                }
                result[kind][id] = merged
                if !fields.isEmpty { conflicts.append(.init(kind: kind, recordID: id, fields: fields, local: l, remote: r)) }
            }
        }
        // A completion is a fact about a goal/day, even when two phones give it different UUIDs.
        for kind in [GoalsSyncKind.completions, .intentions, .journal] {
            var seen: [String: String] = [:]
            let sorted = result[kind].keys.sorted { a, b in
                let ar = remote[kind][a] != nil, br = remote[kind][b] != nil
                return ar == br ? a < b : ar
            }
            for id in sorted {
                guard let record = result[kind][id] else { continue }
                let key = kind == .journal ? (record["kindRaw"]?.text ?? "") + ":" + (record["periodKey"]?.text ?? "")
                    : (record["goalId"]?.text ?? "") + ":" + (record["day"]?.text ?? "")
                if let existingID = seen[key], let existing = result[kind][existingID] {
                    let same = kind == .completions || (kind == .intentions && record["cueRaw"] == existing["cueRaw"])
                        || (kind == .journal && record["text"] == existing["text"] && record["insight"] == existing["insight"])
                    if !same {
                        conflicts.append(.init(kind: kind, recordID: id, fields: ["record"], local: record, remote: existing))
                        if preferLocal == true { var chosen = record; chosen["id"] = .string(existingID); result[kind][existingID] = chosen }
                    }
                    result[kind].removeValue(forKey: id)
                } else { seen[key] = id }
            }
        }
        for kind in [GoalsSyncKind.completions, .intentions] {
            for (id, record) in result[kind] {
                guard case .string(let goalID) = record["goalId"], result[.goals][goalID] == nil else { continue }
                conflicts.append(.init(kind: kind, recordID: id, fields: ["goalId"], local: record, remote: nil))
                if preferLocal == true, let parent = local[.goals][goalID] ?? base[.goals][goalID] { result[.goals][goalID] = parent }
                else if preferLocal == false { result[kind].removeValue(forKey: id) }
            }
        }
        if !conflicts.isEmpty && preferLocal == nil { throw GoalsSyncConflict(entries: conflicts) }
        return result
    }
}

enum GoalsSyncCoding {
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .custom { date, encoder in
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var c = encoder.singleValueContainer(); try c.encode(f.string(from: date))
        }
        return e
    }
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer(), value = try c.decode(String.self)
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = f.date(from: value) ?? ISO8601DateFormatter().date(from: value) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid sync date")
            }
            return date
        }
        return d
    }
    static func record<T: Encodable>(_ value: T, nullable: [String] = []) throws -> GoalsSyncRecord {
        var record = try decoder().decode(GoalsSyncRecord.self, from: encoder().encode(value))
        for key in nullable where record[key] == nil { record[key] = .null }
        return record
    }
    static func day(_ date: Date, calendar: Calendar) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    static func date(_ day: String, calendar: Calendar) throws -> Date {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        guard let value = f.date(from: day), f.string(from: value) == day else { throw CocoaError(.coderReadCorrupt) }
        return value
    }
}
