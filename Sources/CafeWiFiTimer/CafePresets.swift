import Foundation

/// 1つのWi-Fi（カフェ）の定義。
/// limitMinutes が nil の場合は時間無制限（カウントダウンしない）。
struct CafePreset: Codable, Equatable {
    var name: String          // 表示名（例: スターバックス）
    var ssid: String          // ネットワーク名（SSID）
    var limitMinutes: Int?    // 制限時間（分）。nil = 無制限
    var enabled: Bool = true  // 自動検知の有効/無効
}

/// プリセットの管理。ビルトイン定義 + ユーザー設定を UserDefaults に保存する。
/// ネットワーク通信は一切行わず、すべて端末内（ローカル）で完結する。
enum CafePresets {
    /// 主要カフェチェーンのビルトイン定義。
    /// SSID・制限時間は店舗やプロバイダの仕様変更で変わり得るため、
    /// アプリ内（設定ファイル）でユーザーが自由に編集できる。
    static let builtIn: [CafePreset] = [
        .init(name: "スターバックス",   ssid: "at_STARBUCKS_Wi2",  limitMinutes: 60),
        .init(name: "マクドナルド",     ssid: "00_MCD-FREE-WIFI",  limitMinutes: 60),
        .init(name: "ドトール",         ssid: "DOUTOR_FREE_Wi-Fi", limitMinutes: 60),
        .init(name: "タリーズ",         ssid: "tullys_Wi-Fi",      limitMinutes: nil),
        .init(name: "コメダ珈琲店",     ssid: "Komeda_Wi-Fi",      limitMinutes: 60),
        .init(name: "サンマルクカフェ", ssid: "FreeWiFi_SAINTMARC", limitMinutes: 60),
        .init(name: "エクセルシオール", ssid: "EXCELSIOR_FREE_Wi-Fi", limitMinutes: 60),
    ]

    private static let storageKey = "cafePresets.v1"

    /// 保存済みプリセットを読み込む。未保存ならビルトインを返す。
    static func load() -> [CafePreset] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let saved = try? JSONDecoder().decode([CafePreset].self, from: data),
            !saved.isEmpty
        else {
            return builtIn
        }
        return saved
    }

    /// プリセットを保存する。
    static func save(_ presets: [CafePreset]) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// 設定ファイル（JSON）の保存先パス。ユーザーが手で編集できるよう書き出す。
    static var configFileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CafeWiFiTimer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cafes.json")
    }

    /// 現在のプリセットを人間が読める JSON ファイルとして書き出す。
    static func exportToFile(_ presets: [CafePreset]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(presets) else { return }
        try? data.write(to: configFileURL)
    }
}
