import Foundation
import UserNotifications

/// macOS通知センターへの通知。残り時間が少なくなったことを知らせる。
/// バンドル化された .app として実行された場合に動作する。
enum Notifier {

    /// 通知の許可を要求する。
    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 通知を送る。
    static func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "cafewifi-" + title,
            content: content,
            trigger: nil // 即時
        )
        UNUserNotificationCenter.current().add(request)
    }
}
