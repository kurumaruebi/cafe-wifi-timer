import Foundation
import ServiceManagement

/// 「ログイン時に自動起動」（ログイン項目）の登録・解除を管理する。
/// macOS 13以降の SMAppService を使う。.app バンドルとして実行されている必要がある。
enum LoginItem {

    /// 現在ログイン項目に登録されているか。
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 自動起動の有効/無効を切り替える。成功すれば true。
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            NSLog("LoginItem: 切り替えに失敗しました - \(error.localizedDescription)")
            return false
        }
    }
}
