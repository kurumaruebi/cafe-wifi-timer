import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let monitor = WiFiMonitor()
    private var presets: [CafePreset] = CafePresets.load()

    private var session: CountdownSession?
    /// すでに通知を送った残り分のしきい値（重複通知の防止）。
    private var notifiedThresholds: Set<Int> = []
    private var uiTimer: Timer?

    /// 通知を出す残り時間のしきい値（分）。
    private let notifyThresholds = [5, 1]

    // MARK: - 起動

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        Notifier.requestAuthorization()

        monitor.onSSIDChange = { [weak self] ssid in
            self?.handleSSIDChange(ssid)
        }
        monitor.onAuthorizationChange = { [weak self] _ in
            self?.rebuildMenu()
            self?.updateDisplay()
        }
        monitor.start()

        // 表示更新用の毎秒タイマー。
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        uiTimer = timer

        updateDisplay()
    }

    // MARK: - ステータスバー

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        rebuildMenu()
        updateDisplay()
    }

    /// メニューバーの表示（アイコン・残り時間）を更新する。
    private func updateDisplay() {
        guard let button = statusItem.button else { return }

        let icon = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: "Cafe Wi-Fi Timer")
        icon?.isTemplate = true
        button.image = icon
        button.imagePosition = .imageLeading

        guard let session else {
            // アイドル状態：残り時間は表示しない。
            button.attributedTitle = NSAttributedString(string: "")
            return
        }

        let now = Date()
        let text: String
        var color: NSColor = .labelColor

        if let remaining = session.remaining(now: now) {
            text = " " + Self.format(remaining)
            if remaining <= 60 {
                color = .systemRed
            } else if remaining <= 5 * 60 {
                color = .systemOrange
            }
        } else {
            // 無制限カフェ
            text = " ∞"
        }

        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        button.attributedTitle = NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color]
        )
    }

    /// 秒数を mm:ss 形式にする。
    private static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - メニュー

    private func rebuildMenu() {
        let menu = NSMenu()

        // 現在の状態表示（操作不可の情報行）。
        menu.addItem(makeInfoItem())
        menu.addItem(.separator())

        // 手動開始
        let manual = NSMenuItem(title: "手動で60分タイマーを開始", action: #selector(startManual), keyEquivalent: "")
        manual.target = self
        menu.addItem(manual)

        // 開始時刻のズレを手動補正する（自動で正確に取れなかった場合の保険）。
        if let session, session.limitMinutes != nil {
            let adjustItem = NSMenuItem(title: "開始時刻を調整（ズレ補正）", action: nil, keyEquivalent: "")
            let adjustMenu = NSMenu()
            for m in [5, 10, 15] {
                let earlier = NSMenuItem(
                    title: "実際は\(m)分前に接続していた（残り −\(m)分）",
                    action: #selector(adjustEarlier(_:)),
                    keyEquivalent: ""
                )
                earlier.target = self
                earlier.tag = m
                adjustMenu.addItem(earlier)
            }
            adjustMenu.addItem(.separator())
            let later = NSMenuItem(title: "5分戻す（残り ＋5分）", action: #selector(adjustLater(_:)), keyEquivalent: "")
            later.target = self
            later.tag = 5
            adjustMenu.addItem(later)
            adjustItem.submenu = adjustMenu
            menu.addItem(adjustItem)
        }

        if session != nil {
            let reset = NSMenuItem(title: "リセット（タイマー停止）", action: #selector(resetSession), keyEquivalent: "")
            reset.target = self
            menu.addItem(reset)
        }

        menu.addItem(.separator())

        // 対象カフェのトグル
        let cafesItem = NSMenuItem(title: "対象カフェ（自動検知）", action: nil, keyEquivalent: "")
        let cafesMenu = NSMenu()
        for (index, preset) in presets.enumerated() {
            let limitText = preset.limitMinutes.map { "\($0)分" } ?? "無制限"
            let item = NSMenuItem(
                title: "\(preset.name)（\(limitText)）",
                action: #selector(toggleCafe(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.state = preset.enabled ? .on : .off
            item.tag = index
            cafesMenu.addItem(item)
        }
        cafesItem.submenu = cafesMenu
        menu.addItem(cafesItem)

        // ログイン時に自動起動（常駐運用のためのトグル）
        let loginItem = NSMenuItem(title: "ログイン時に自動起動（常駐・推奨）", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(loginItem)

        // 設定ファイルを書き出して開く
        let exportItem = NSMenuItem(title: "設定ファイルを書き出して開く", action: #selector(openConfigFile), keyEquivalent: "")
        exportItem.target = self
        menu.addItem(exportItem)

        // 位置情報が未許可なら誘導
        if !monitor.isAuthorized {
            let authItem = NSMenuItem(title: "⚠️ 位置情報を許可（SSID検知に必要）", action: #selector(requestLocation), keyEquivalent: "")
            authItem.target = self
            menu.addItem(authItem)
        }

        menu.addItem(.separator())

        let about = NSMenuItem(title: "CafeWiFiTimer について", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func makeInfoItem() -> NSMenuItem {
        let title: String
        if let session {
            let now = Date()
            if let remaining = session.remaining(now: now) {
                title = "☕️ \(session.cafeName)：残り \(Self.format(remaining))"
            } else {
                title = "☕️ \(session.cafeName)：時間無制限"
            }
        } else if let ssid = monitor.currentSSID {
            title = "接続中: \(ssid)（対象外）"
        } else if !monitor.isAuthorized {
            title = "SSID未取得（位置情報の許可が必要）"
        } else {
            title = "Wi-Fi未接続"
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: - タイマー処理

    private func tick() {
        guard let session else { return }
        let now = Date()

        // 残り時間に応じた通知。
        if let remaining = session.remaining(now: now) {
            let remainingMinutes = Int(remaining / 60)
            for threshold in notifyThresholds where remaining > 0 {
                if remainingMinutes < threshold && !notifiedThresholds.contains(threshold) {
                    notifiedThresholds.insert(threshold)
                    Notifier.send(
                        title: "Wi-Fi残り\(threshold)分",
                        body: "\(session.cafeName) の無料Wi-Fiの制限時間まであと\(threshold)分です。"
                    )
                }
            }

            if session.isExpired(now: now) && !notifiedThresholds.contains(0) {
                notifiedThresholds.insert(0)
                Notifier.send(
                    title: "Wi-Fi制限時間に到達",
                    body: "\(session.cafeName) の無料Wi-Fiの制限時間（\(session.limitMinutes ?? 0)分）に達しました。再接続が必要な場合があります。"
                )
            }
        }

        updateDisplay()
        // 情報行も更新するためメニューが開いていれば作り直す必要はないが、
        // 軽量なので開くたびに rebuild される設計（statusItem.menu 経由）に任せる。
    }

    // MARK: - SSID変化

    private func handleSSIDChange(_ ssid: String?) {
        defer {
            rebuildMenu()
            updateDisplay()
        }

        guard let ssid else {
            // 切断：自動開始したセッションを終了し、接続記録もクリアする。
            // 記録を消すことで、Wi-Fiを OFF→ON して再接続したときは
            // 古い開始時刻を引き継がず、60:00 から正しくカウントし直す。
            endAutoSession()
            return
        }

        // 対象カフェにマッチするか。
        guard let preset = presets.first(where: { $0.enabled && $0.ssid == ssid }) else {
            // 対象外のWi-Fi。自動セッションを終了し、接続記録もクリアする。
            endAutoSession()
            return
        }

        // すでに同じSSIDのセッション中なら何もしない（重複開始の防止）。
        if session?.ssid == ssid { return }

        let bssid = monitor.currentBSSID
        let start: Date

        if let record = ConnectionStore.load(), record.ssid == ssid, record.bssid == bssid {
            // 同じ接続（SSID＋BSSID）の継続。アプリを再起動しても開始時刻を引き継ぐ。
            // 常駐していれば、ここに最初に来た時刻＝ポータル同意で接続が完了した時刻になる。
            start = record.startedAt
        } else {
            // はじめて見る接続。常駐運用なら now ≒ 接続した瞬間。
            // アプリ未起動中に接続していた場合の保険として DHCP リース時刻も試す。
            start = estimatedConnectStart()
            ConnectionStore.save(ConnectionRecord(ssid: ssid, bssid: bssid, startedAt: start))
        }

        startSession(
            cafeName: preset.name,
            ssid: ssid,
            limitMinutes: preset.limitMinutes,
            startedAt: start
        )
    }

    /// 初回接続時のカウント開始時刻を推定する。
    /// DHCPリース開始時刻が取得でき、それが過去であればそれを採用する。
    /// （リースが短い回線では不正確になり得るため、手動調整で補正できるようにしている）
    private func estimatedConnectStart() -> Date {
        let now = Date()
        guard let lease = DHCPInfo.leaseStartTime() else { return now }
        // 未来の値（時計のずれ等）は採用しない。
        return lease <= now ? lease : now
    }

    /// 自動開始したセッションを終了し、接続記録（永続化）もクリアする。
    /// Wi-Fi切断・対象外ネットワークへの移動で呼ばれる。
    /// 手動セッション（ssid == nil）は切断と無関係なので残す。
    private func endAutoSession() {
        guard session?.ssid != nil else { return }
        session = nil
        notifiedThresholds.removeAll()
        ConnectionStore.clear()
    }

    private func startSession(cafeName: String, ssid: String?, limitMinutes: Int?, startedAt: Date) {
        session = CountdownSession(
            cafeName: cafeName,
            ssid: ssid,
            limitMinutes: limitMinutes,
            startedAt: startedAt
        )
        notifiedThresholds.removeAll()
    }

    // MARK: - メニューアクション

    @objc private func startManual() {
        startSession(cafeName: "手動", ssid: nil, limitMinutes: 60, startedAt: Date())
        rebuildMenu()
        updateDisplay()
    }

    @objc private func resetSession() {
        session = nil
        notifiedThresholds.removeAll()
        ConnectionStore.clear()
        rebuildMenu()
        updateDisplay()
    }

    /// 「実際はもっと前に接続していた」分だけ開始時刻を過去にずらす（残り時間が減る）。
    @objc private func adjustEarlier(_ sender: NSMenuItem) {
        shiftStart(byMinutes: -sender.tag)
    }

    /// 早めすぎたときに開始時刻を戻す（残り時間が増える）。
    @objc private func adjustLater(_ sender: NSMenuItem) {
        shiftStart(byMinutes: sender.tag)
    }

    /// 開始時刻を指定分ずらし、永続記録も更新する。
    private func shiftStart(byMinutes minutes: Int) {
        guard let current = session else { return }
        let newStart = current.startedAt.addingTimeInterval(Double(minutes) * 60)
        session = CountdownSession(
            cafeName: current.cafeName,
            ssid: current.ssid,
            limitMinutes: current.limitMinutes,
            startedAt: newStart
        )
        if let ssid = current.ssid {
            ConnectionStore.save(ConnectionRecord(ssid: ssid, bssid: monitor.currentBSSID, startedAt: newStart))
        }
        notifiedThresholds.removeAll()
        rebuildMenu()
        updateDisplay()
    }

    @objc private func toggleCafe(_ sender: NSMenuItem) {
        let index = sender.tag
        guard presets.indices.contains(index) else { return }
        presets[index].enabled.toggle()
        CafePresets.save(presets)
        // 現在接続中のSSIDで再判定。
        monitor.refresh()
        handleSSIDChange(monitor.currentSSID)
    }

    @objc private func toggleLoginItem() {
        let target = !LoginItem.isEnabled
        let success = LoginItem.setEnabled(target)
        if !success {
            let alert = NSAlert()
            alert.messageText = "自動起動の設定に失敗しました"
            alert.informativeText = "「システム設定 → 一般 → ログイン項目」から手動で CafeWiFiTimer を追加してください。"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        rebuildMenu()
    }

    @objc private func openConfigFile() {
        CafePresets.exportToFile(presets)
        NSWorkspace.shared.activateFileViewerSelecting([CafePresets.configFileURL])
    }

    @objc private func requestLocation() {
        monitor.requestAuthorization()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "CafeWiFiTimer"
        alert.informativeText = """
        カフェの無料Wi-Fiの制限時間（多くは60分）の残り時間を、メニューバーに表示します。

        ・対象SSIDに接続すると自動でカウントダウンを開始します。
        ・接続時刻を記録し、アプリを再起動してもカウントを引き継ぎます。
        ・ネットワーク通信は一切行いません（完全ローカル動作）。
        ・位置情報はSSIDの判定だけに使い、外部送信しません。

        ＜正確に使うコツ＞
        「ログイン項目」に追加して常駐させてください。常駐していれば、ポータルで同意して接続が完了した瞬間の時刻を正確に記録できます。
        アプリ未起動中に接続していた場合など、開始時刻がずれているときは、メニューの「開始時刻を調整」で手動補正できます。

        SSID・制限時間は「設定ファイルを書き出して開く」から編集できます。
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
