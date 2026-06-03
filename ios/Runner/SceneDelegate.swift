import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

    private var pendingCode: String?
    private var pendingState: String?

    // Cold-start: app launched by the custom URL scheme.
    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let url = connectionOptions.urlContexts.first?.url,
           isTelegramRedirect(url) {
            extractAndQueue(url: url)
        }
        super.scene(scene, willConnectTo: session, options: connectionOptions)
    }

    // Warm-resume: custom URL scheme fired while app is in memory.
    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        super.scene(scene, openURLContexts: URLContexts)
        guard let url = URLContexts.first?.url, isTelegramRedirect(url) else { return }
        if !deliver(url: url) { extractAndQueue(url: url) }
    }

    // Drain the queue once the scene is active (Flutter engine is ready).
    override func sceneDidBecomeActive(_ scene: UIScene) {
        super.sceneDidBecomeActive(scene)
        if let code = pendingCode, let state = pendingState {
            if deliverParams(code: code, state: state) {
                pendingCode = nil
                pendingState = nil
            }
        }
    }

    // MARK: - Helpers

    private func isTelegramRedirect(_ url: URL) -> Bool {
        url.scheme == "yoollive" && url.host == "tglogin"
    }

    private func extractAndQueue(url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code  = comps.queryItems?.first(where: { $0.name == "code"  })?.value,
              let state = comps.queryItems?.first(where: { $0.name == "state" })?.value
        else { return }
        pendingCode  = code
        pendingState = state
    }

    @discardableResult
    private func deliver(url: URL) -> Bool {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code  = comps.queryItems?.first(where: { $0.name == "code"  })?.value,
              let state = comps.queryItems?.first(where: { $0.name == "state" })?.value
        else { return false }
        return deliverParams(code: code, state: state)
    }

    @discardableResult
    private func deliverParams(code: String, state: String) -> Bool {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return false
        }
        FlutterMethodChannel(
            name: "yool.live.app/telegram_auth",
            binaryMessenger: controller.binaryMessenger
        ).invokeMethod("onTelegramCallback", arguments: ["code": code, "state": state])
        return true
    }
}
