import EventKit
import Foundation

enum ReminderBookError: LocalizedError {
    case notAllowed
    case noList

    var errorDescription: String? {
        switch self {
        case .notAllowed: return "Quasi is not allowed to add reminders. Allow it in Settings → Privacy & Security → Reminders."
        case .noList: return "There is no list in Reminders to add to."
        }
    }
}

/// Adds the notes that say "remind me…" to Apple Reminders, in the default list, with an alert
/// at the time said. Nothing leaves the phone here; Reminders syncs as it always does.
enum ReminderBook {
    private static let store = EKEventStore()

    static var isAllowed: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }
    static var isUndecided: Bool { EKEventStore.authorizationStatus(for: .reminder) == .notDetermined }

    /// Asks for access the first time. Has to be called with the app in front.
    @discardableResult
    static func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToReminders()) ?? false
    }

    /// Adds the reminder and returns its id.
    static func add(_ draft: TaskDraft, transcript: String, recordedAt: Date) throws -> String {
        guard isAllowed else { throw ReminderBookError.notAllowed }
        guard let list = store.defaultCalendarForNewReminders() else { throw ReminderBookError.noList }
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = list
        reminder.title = draft.title
        let voiceNote = "Voice note, \(recordedAt.formatted(date: .abbreviated, time: .shortened)):\n\(transcript)"
        reminder.notes = ([draft.notes] + [voiceNote]).filter { !$0.isEmpty }.joined(separator: "\n\n")
        reminder.priority = [0: 0, 1: 1, 2: 1, 3: 5, 4: 9][draft.priority] ?? 0

        if let day = date(draft.dueDate) {
            var parts = Calendar.current.dateComponents([.year, .month, .day], from: day)
            if let (hour, minute) = time(draft.dueTime) {
                parts.hour = hour
                parts.minute = minute
                if let moment = Calendar.current.date(from: parts) { reminder.addAlarm(EKAlarm(absoluteDate: moment)) }
            }
            reminder.dueDateComponents = parts
        }
        if let rule = recurrence(draft.recurrence) { reminder.addRecurrenceRule(rule) }
        try store.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }

    /// Removes a reminder this app added. One that is already gone counts as removed.
    static func remove(_ id: String) throws {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        try store.remove(reminder, commit: true)
    }

    private static func date(_ text: String) -> Date? {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "yyyy-MM-dd"
        return text.isEmpty ? nil : format.date(from: text)
    }

    private static func time(_ text: String) -> (Int, Int)? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }

    /// The repeats the extractor writes ("every day", "every 2 weeks", "every monday and thursday")
    /// as a rule Reminders understands; nil for anything else.
    static func recurrence(_ phrase: String) -> EKRecurrenceRule? {
        let words = phrase.lowercased().split(separator: " ").map(String.init).filter { $0 != "and" }
        guard words.first == "every", words.count >= 2 else { return nil }
        let days: [String: EKWeekday] = ["monday": .monday, "tuesday": .tuesday, "wednesday": .wednesday, "thursday": .thursday,
                                         "friday": .friday, "saturday": .saturday, "sunday": .sunday]
        let frequencies: [String: EKRecurrenceFrequency] = ["day": .daily, "week": .weekly, "month": .monthly, "year": .yearly]
        let rest = Array(words.dropFirst())
        if rest == ["weekday"] {
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1,
                                    daysOfTheWeek: [.monday, .tuesday, .wednesday, .thursday, .friday].map { EKRecurrenceDayOfWeek($0) },
                                    daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: nil)
        }
        let weekdays = rest.compactMap { days[$0] }
        if !weekdays.isEmpty, weekdays.count == rest.count {
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, daysOfTheWeek: weekdays.map { EKRecurrenceDayOfWeek($0) },
                                    daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: nil)
        }
        // "every day", "every 2 weeks", "every month on the 15th" (the day comes from the due date).
        let interval = Int(rest[0]) ?? 1
        let unit = (Int(rest[0]) == nil ? rest[0] : rest.count > 1 ? rest[1] : "").replacingOccurrences(of: "s", with: "", options: .anchored.union(.backwards))
        guard let frequency = frequencies[unit] else { return nil }
        return EKRecurrenceRule(recurrenceWith: frequency, interval: interval, end: nil)
    }
}
