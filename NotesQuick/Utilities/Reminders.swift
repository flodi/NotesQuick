import Foundation
import UserNotifications

/// Local notification reminders, keyed by "remind:<file name>".
enum Reminders {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private static func id(for name: String) -> String { "remind:" + name }

    static func schedule(name: String, title: String, date: Date) {
        guard date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "NotesQuick"
        content.body = title
        content.sound = .default
        content.userInfo = ["file": name]
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id(for: name), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel(name: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id(for: name)])
    }

    /// Reconcile scheduled notifications with the current schedule index.
    static func sync(_ map: [String: ItemSchedule], titleFor: @escaping (String) -> String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let pendingIds = Set(pending.map { $0.identifier })
            for (name, sched) in map {
                let ident = id(for: name)
                if let date = sched.remindAt, date > Date() {
                    if !pendingIds.contains(ident) {
                        schedule(name: name, title: titleFor(name), date: date)
                    }
                } else if pendingIds.contains(ident) {
                    cancel(name: name)
                }
            }
            // Cancel reminders whose item no longer has one.
            for ident in pendingIds where ident.hasPrefix("remind:") {
                let name = String(ident.dropFirst("remind:".count))
                if map[name]?.remindAt == nil {
                    center.removePendingNotificationRequests(withIdentifiers: [ident])
                }
            }
        }
    }
}
