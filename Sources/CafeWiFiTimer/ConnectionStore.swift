import Foundation

/// 進行中の接続の記録。アプリ再起動をまたいでカウントを継続するために永続化する。
/// SSID と BSSID（接続先アクセスポイント）が一致する限り「同じ接続」とみなす。
struct ConnectionRecord: Codable, Equatable {
    let ssid: String
    let bssid: String?
    let startedAt: Date
}

/// 接続記録を UserDefaults に保存・復元する。ネットワーク通信は行わない。
enum ConnectionStore {
    private static let key = "activeConnection.v1"

    static func load() -> ConnectionRecord? {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let record = try? JSONDecoder().decode(ConnectionRecord.self, from: data)
        else { return nil }
        return record
    }

    static func save(_ record: ConnectionRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
