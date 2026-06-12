import AppKit

// メニューバー常駐アプリ（Dockアイコン・メニューバーを持たない）として起動する。
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
