import Foundation

/// 進行中のカウントダウン1回分の状態。
struct CountdownSession {
    let cafeName: String       // 表示名（例: スターバックス / 手動）
    let ssid: String?          // 紐づくSSID（手動開始時は nil のこともある）
    let limitMinutes: Int?     // 制限時間（分）。nil = 無制限
    let startedAt: Date        // カウント開始時刻

    /// 残り秒数。無制限の場合は nil。0未満にはならない。
    func remaining(now: Date) -> TimeInterval? {
        guard let minutes = limitMinutes else { return nil }
        let total = TimeInterval(minutes * 60)
        return max(0, total - now.timeIntervalSince(startedAt))
    }

    /// 経過して時間切れになったか。
    func isExpired(now: Date) -> Bool {
        guard let remaining = remaining(now: now) else { return false }
        return remaining <= 0
    }
}
