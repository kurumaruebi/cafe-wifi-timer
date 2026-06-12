import Foundation
import CoreWLAN
import CoreLocation

/// 接続中のWi-Fi（SSID）を監視する。
///
/// macOS 14（Sonoma）以降では、アプリがSSIDを取得するために
/// 「位置情報サービス」の許可が必要になった。本アプリは位置情報を
/// SSIDの判定だけに使い、座標の取得・保存・外部送信は一切行わない。
final class WiFiMonitor: NSObject, CLLocationManagerDelegate, CWEventDelegate {

    /// SSIDが変化したとき（接続・切断・別ネットワークへ移動）に呼ばれる。
    /// 切断時は nil が渡る。
    var onSSIDChange: ((String?) -> Void)?

    /// 位置情報の認可状態が変わったときに呼ばれる。
    var onAuthorizationChange: ((Bool) -> Void)?

    private let locationManager = CLLocationManager()
    private let wifiClient = CWWiFiClient.shared()
    private var pollTimer: Timer?

    private(set) var currentSSID: String?
    private(set) var currentBSSID: String?
    private(set) var isAuthorized = false

    override init() {
        super.init()
        locationManager.delegate = self
        isAuthorized = Self.authorized(locationManager.authorizationStatus)
    }

    /// 監視を開始する。位置情報の許可を要求し、Wi-Fiイベントを購読する。
    func start() {
        requestAuthorization()

        // CoreWLANのイベントを購読し、接続/切断を「即時」に検知する。
        wifiClient.delegate = self
        do {
            try wifiClient.startMonitoringEvent(with: .ssidDidChange)
            try wifiClient.startMonitoringEvent(with: .bssidDidChange)
            try wifiClient.startMonitoringEvent(with: .linkDidChange)
        } catch {
            // イベント購読に失敗してもポーリングで動作する。
            NSLog("WiFiMonitor: イベント購読に失敗 - \(error.localizedDescription)")
        }

        // イベントの取りこぼし対策として、10秒ごとのポーリングも併用する。
        let timer = Timer(timeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        poll()
    }

    /// 位置情報の許可ダイアログを表示する（未許可の場合）。
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 現在のSSIDを即時に取り直す（メニュー操作時など）。
    func refresh() {
        poll()
    }

    // MARK: - 内部処理

    private func poll() {
        let iface = wifiClient.interface()
        let ssid = iface?.ssid()
        // BSSID も更新しておく（接続先APの識別に使う）。onSSIDChange より先に更新する。
        currentBSSID = iface?.bssid()
        if ssid != currentSSID {
            currentSSID = ssid
            onSSIDChange?(ssid)
        }
    }

    private static func authorized(_ status: CLAuthorizationStatus) -> Bool {
        switch status {
        case .authorizedAlways:
            return true
        case .authorized: // macOSの一部バージョンで使われる
            return true
        default:
            return false
        }
    }

    // MARK: - CWEventDelegate（接続/切断の即時通知）

    func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        pollOnMain()
    }

    func bssidDidChangeForWiFiInterface(withName interfaceName: String) {
        pollOnMain()
    }

    func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        pollOnMain()
    }

    /// イベントは別スレッドで届くため、メインスレッドでSSIDを取り直す。
    private func pollOnMain() {
        DispatchQueue.main.async { [weak self] in
            self?.poll()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorized = Self.authorized(manager.authorizationStatus)
        isAuthorized = authorized
        onAuthorizationChange?(authorized)
        // 許可された直後はSSIDが取れるようになるので取り直す。
        poll()
    }
}
