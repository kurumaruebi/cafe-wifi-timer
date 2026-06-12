import Foundation
import CoreWLAN

/// DHCP（IPアドレス取得）の情報をローカルから読み取る。
/// ネットワーク通信は行わず、システムが保持する状態（ipconfig）を参照するだけ。
enum DHCPInfo {

    /// 現在のWi-FiインターフェースのDHCPリース開始時刻を返す。
    ///
    /// これは「IPアドレスを取得した時刻」で、多くの場合 Wi-Fi 接続時刻の
    /// 良い近似になる。ただしDHCPリースが短い回線では「直近のリース更新時刻」に
    /// なり、実際の接続時刻より新しくなる（残り時間が多めに出る）ことがある。
    /// 取得できない場合は nil。
    static func leaseStartTime() -> Date? {
        guard let interface = CWWiFiClient.shared().interface()?.interfaceName else { return nil }
        guard let summary = runIpconfigSummary(interface: interface) else { return nil }
        return parseLeaseStartTime(from: summary)
    }

    /// `ipconfig getsummary <interface>` を実行して出力を得る（ローカル状態の参照）。
    private static func runIpconfigSummary(interface: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ipconfig")
        process.arguments = ["getsummary", interface]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// 出力から `LeaseStartTime : 06/12/2026 12:31:27` の日時を取り出す。
    private static func parseLeaseStartTime(from summary: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MM/dd/yyyy HH:mm:ss"

        for rawLine in summary.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("LeaseStartTime") else { continue }
            // "LeaseStartTime : 06/12/2026 12:31:27" → 値部分を取り出す
            let parts = line.components(separatedBy: " : ")
            guard parts.count >= 2 else { continue }
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            return formatter.date(from: value)
        }
        return nil
    }
}
