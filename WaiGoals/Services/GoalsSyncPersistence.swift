import Foundation
import SwiftData

private struct SyncGoal: Codable {
    var id: String; var title: String; var personalWhy: String?; var smallStep: String?
    var symbol: String; var colorToken: String; var emotionRawValue: String?
    var scheduleTypeRaw: Int; var scheduledWeekdaysRaw: [Int]; var weeklyTarget: Int
    var reminderEnabled: Bool; var reminderTime: Date?; var sortIndex: Int; var createdAt: Date; var isArchived: Bool
    @MainActor init(_ g: Goal) {
        id=g.id.uuidString.lowercased(); title=g.title; personalWhy=g.personalWhy; smallStep=g.smallStep
        symbol=g.symbol; colorToken=g.colorToken; emotionRawValue=g.emotionRawValue
        scheduleTypeRaw=g.scheduleTypeRaw; scheduledWeekdaysRaw=g.scheduledWeekdaysRaw; weeklyTarget=g.weeklyTarget
        reminderEnabled=g.reminderEnabled; reminderTime=g.reminderTime; sortIndex=g.sortIndex; createdAt=g.createdAt; isArchived=g.isArchived
    }
    @MainActor func apply(_ g: Goal) {
        g.title=title; g.personalWhy=personalWhy; g.smallStep=smallStep; g.symbol=symbol; g.colorToken=colorToken
        g.emotionRawValue=emotionRawValue; g.scheduleTypeRaw=scheduleTypeRaw; g.scheduledWeekdaysRaw=scheduledWeekdaysRaw
        g.weeklyTarget=weeklyTarget; g.reminderEnabled=reminderEnabled; g.reminderTime=reminderTime
        g.sortIndex=sortIndex; g.createdAt=createdAt; g.isArchived=isArchived
    }
}
private struct SyncCompletion: Codable { var id: String; var goalId: String; var day: String }
private struct SyncIntention: Codable { var id: String; var goalId: String; var day: String; var cueRaw: String; var approvedAt: Date }
private struct SyncJournal: Codable {
    var id: String; var kindRaw: String; var periodKey: String; var text: String; var insight: String?
    var createdAt: Date; var updatedAt: Date
}
private struct SyncAchievement: Codable { var id: String; var unlockedAt: Date }

@MainActor
extension GoalsSyncDocument {
    static func capture(_ context: ModelContext, calendar: Calendar = .current) throws -> Self {
        var document = Self()
        func add(_ kind: GoalsSyncKind, _ id: String, _ record: GoalsSyncRecord) throws {
            guard document[kind][id] == nil else { throw CocoaError(.coderReadCorrupt) }
            document[kind][id] = record
        }
        for g in try context.fetch(FetchDescriptor<Goal>()) {
            try add(.goals, g.id.uuidString.lowercased(), GoalsSyncCoding.record(SyncGoal(g), nullable: ["personalWhy","smallStep","emotionRawValue","reminderTime"]))
        }
        for c in try context.fetch(FetchDescriptor<Completion>()) {
            guard let g = c.goal else { throw CocoaError(.coderReadCorrupt) }
            let day = c.syncDay ?? GoalsSyncCoding.day(c.day, calendar: calendar); c.syncDay = day
            try add(.completions, c.id.uuidString.lowercased(), GoalsSyncCoding.record(SyncCompletion(id:c.id.uuidString.lowercased(),goalId:g.id.uuidString.lowercased(),day:day)))
        }
        for i in try context.fetch(FetchDescriptor<Intention>()) {
            guard let g = i.goal else { throw CocoaError(.coderReadCorrupt) }
            let day = i.syncDay ?? GoalsSyncCoding.day(i.day, calendar: calendar); i.syncDay = day
            try add(.intentions, i.id.uuidString.lowercased(), GoalsSyncCoding.record(SyncIntention(id:i.id.uuidString.lowercased(),goalId:g.id.uuidString.lowercased(),day:day,cueRaw:i.cueRaw,approvedAt:i.approvedAt)))
        }
        for j in try context.fetch(FetchDescriptor<JournalEntry>()) {
            try add(.journal, j.id.uuidString.lowercased(), GoalsSyncCoding.record(SyncJournal(id:j.id.uuidString.lowercased(),kindRaw:j.kindRaw,periodKey:j.periodKey,text:j.text,insight:j.insight,createdAt:j.createdAt,updatedAt:j.updatedAt), nullable:["insight"]))
        }
        for a in try context.fetch(FetchDescriptor<AchievementUnlock>()) {
            try add(.achievements, a.achievementRawValue, GoalsSyncCoding.record(SyncAchievement(id:a.achievementRawValue,unlockedAt:a.unlockedAt)))
        }
        return document
    }
    func apply(to context: ModelContext, calendar: Calendar = .current) throws {
        func decode<T: Decodable>(_ kind: GoalsSyncKind, _: T.Type) throws -> [String:T] {
            try self[kind].mapValues { try GoalsSyncCoding.decoder().decode(T.self, from: GoalsSyncCoding.encoder().encode($0)) }
        }
        let goals = try decode(.goals, SyncGoal.self), completions = try decode(.completions, SyncCompletion.self)
        let intentions = try decode(.intentions, SyncIntention.self), journals = try decode(.journal, SyncJournal.self)
        let achievements = try decode(.achievements, SyncAchievement.self)
        // Validate the entire response before changing a single model.
        for kind in GoalsSyncKind.allCases {
            for (key, record) in self[kind] {
                guard record["id"] == .string(key), kind == .achievements || UUID(uuidString:key) != nil else { throw CocoaError(.coderReadCorrupt) }
            }
        }
        for c in completions.values {
            guard goals[c.goalId] != nil else { throw CocoaError(.coderReadCorrupt) }
            _ = try GoalsSyncCoding.date(c.day, calendar:calendar)
        }
        for i in intentions.values {
            guard goals[i.goalId] != nil else { throw CocoaError(.coderReadCorrupt) }
            _ = try GoalsSyncCoding.date(i.day, calendar:calendar)
        }
        for j in journals.values {
            guard JournalKind(rawValue:j.kindRaw) != nil else { throw CocoaError(.coderReadCorrupt) }
            _ = try GoalsSyncCoding.date(j.periodKey, calendar:calendar)
        }
        func index<T>(_ rows:[T], id:(T)->String) throws -> [String:T] {
            var result:[String:T]=[:]
            for row in rows { guard result[id(row)] == nil else { throw CocoaError(.coderReadCorrupt) }; result[id(row)]=row }
            return result
        }
        var existingGoals = try index(context.fetch(FetchDescriptor<Goal>()),id:{$0.id.uuidString.lowercased()})
        let existingCompletions = try index(context.fetch(FetchDescriptor<Completion>()),id:{$0.id.uuidString.lowercased()})
        let existingIntentions = try index(context.fetch(FetchDescriptor<Intention>()),id:{$0.id.uuidString.lowercased()})
        let existingJournals = try index(context.fetch(FetchDescriptor<JournalEntry>()),id:{$0.id.uuidString.lowercased()})
        let existingAchievements = try index(context.fetch(FetchDescriptor<AchievementUnlock>()),id:{$0.achievementRawValue})
        for (id,c) in existingCompletions where completions[id] == nil { context.delete(c) }
        for (id,i) in existingIntentions where intentions[id] == nil { context.delete(i) }
        for (id,g) in existingGoals where goals[id] == nil { context.delete(g); existingGoals.removeValue(forKey:id) }
        for (id,j) in existingJournals where journals[id] == nil { context.delete(j) }
        for (id,a) in existingAchievements where achievements[id] == nil { context.delete(a) }
        for (id,g) in goals {
            let row = existingGoals[id] ?? Goal(id:UUID(uuidString:id)!,title:g.title)
            if existingGoals[id] == nil { context.insert(row); existingGoals[id]=row }
            g.apply(row)
        }
        for (id,c) in completions {
            let date = try GoalsSyncCoding.date(c.day,calendar:calendar)
            let row = existingCompletions[id] ?? Completion(id:UUID(uuidString:id)!,day:date)
            if existingCompletions[id] == nil { context.insert(row) }
            row.goal=existingGoals[c.goalId]; row.day=date; row.syncDay=c.day
        }
        for (id,i) in intentions {
            let date = try GoalsSyncCoding.date(i.day,calendar:calendar)
            let row = existingIntentions[id] ?? Intention(id:UUID(uuidString:id)!,day:date)
            if existingIntentions[id] == nil { context.insert(row) }
            row.goal=existingGoals[i.goalId]; row.day=date; row.syncDay=i.day; row.cueRaw=i.cueRaw; row.approvedAt=i.approvedAt
        }
        for (id,j) in journals {
            let row = try existingJournals[id] ?? JournalEntry(kind:JournalKind(rawValue:j.kindRaw)!,date:GoalsSyncCoding.date(j.periodKey,calendar:calendar),text:j.text,calendar:calendar)
            if existingJournals[id] == nil { row.id=UUID(uuidString:id)!; context.insert(row) }
            row.kindRaw=j.kindRaw; row.periodKey=j.periodKey; row.text=j.text; row.insight=j.insight; row.createdAt=j.createdAt; row.updatedAt=j.updatedAt
        }
        for (id,a) in achievements {
            let row = existingAchievements[id] ?? AchievementUnlock(rawValue:id,unlockedAt:a.unlockedAt)
            if existingAchievements[id] == nil { context.insert(row) }
            row.unlockedAt=a.unlockedAt
        }
    }
}

struct GoalsSyncRequest: Codable, Sendable {
    var operationId: String; var deviceId: String; var timeZone: String; var lastAppliedRevision: Int; var changes: [GoalsSyncChange]
}
struct GoalsSyncPending: Codable, Sendable { var request: GoalsSyncRequest; var local: GoalsSyncDocument }
struct GoalsSyncResponse: Decodable, Sendable { var revision: Int; var state: GoalsSyncDocument }

@MainActor
final class GoalsSyncSession {
    let context: ModelContext
    let metadata: GoalsSyncMetadata
    let deviceID: UUID
    init(context: ModelContext, accountID: String, deviceID: UUID) throws {
        self.context=context; self.deviceID=deviceID
        let rows=try context.fetch(FetchDescriptor<GoalsSyncMetadata>(predicate:#Predicate{$0.accountID == accountID}))
        guard rows.count <= 1 else { throw CocoaError(.coderReadCorrupt) }
        metadata=rows.first ?? GoalsSyncMetadata(accountID:accountID)
        if rows.isEmpty { context.insert(metadata) }
    }
    func baseline() throws -> GoalsSyncDocument {
        try metadata.baselineData.map { try GoalsSyncCoding.decoder().decode(GoalsSyncDocument.self,from:$0) } ?? GoalsSyncDocument()
    }
    func prepare(calendar: Calendar = .current) throws -> GoalsSyncPending {
        if let data=metadata.pendingData { return try GoalsSyncCoding.decoder().decode(GoalsSyncPending.self,from:data) }
        let local=try GoalsSyncDocument.capture(context,calendar:calendar)
        let pending=GoalsSyncPending(request:GoalsSyncRequest(operationId:UUID().uuidString.lowercased(),deviceId:deviceID.uuidString.lowercased(),
            timeZone:calendar.timeZone.identifier,lastAppliedRevision:metadata.revision,changes:local.changes(since:try baseline())),local:local)
        metadata.pendingData=try GoalsSyncCoding.encoder().encode(pending)
        try context.save()
        return pending
    }
    func accept(_ response: GoalsSyncResponse, pending: GoalsSyncPending, calendar: Calendar = .current) throws {
        let local=try GoalsSyncDocument.capture(context,calendar:calendar)
        let merged=try GoalsSyncDocument.merge(base:pending.local,local:local,remote:response.state)
        try commit(merged,baseline:response,calendar:calendar)
    }
    func resolve(_ response: GoalsSyncResponse, base: GoalsSyncDocument, preferLocal: Bool, calendar: Calendar = .current) throws {
        let local=try GoalsSyncDocument.capture(context,calendar:calendar)
        let merged=try GoalsSyncDocument.merge(base:base,local:local,remote:response.state,preferLocal:preferLocal)
        try commit(merged,baseline:response,calendar:calendar)
    }
    private func commit(_ document: GoalsSyncDocument, baseline: GoalsSyncResponse, calendar: Calendar) throws {
        // Preserve edits made during the request before beginning the atomic local commit.
        try context.save()
        do {
            try document.apply(to:context,calendar:calendar)
            metadata.baselineData=try GoalsSyncCoding.encoder().encode(baseline.state)
            metadata.revision=baseline.revision; metadata.pendingData=nil; metadata.lastSyncedAt = .now
            try context.save()
        } catch { context.rollback(); throw error }
    }
}
