import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    NSLog("[TelegramAuth][SceneDelegate] scene:continue: activityType=%@", userActivity.activityType)
    super.scene(scene, continue: userActivity)

    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL
    else {
      NSLog("[TelegramAuth][SceneDelegate] skipped: not a web browsing activity or no URL")
      return
    }

    NSLog("[TelegramAuth][SceneDelegate] universal link received: %@", url.absoluteString)

    guard url.host?.hasSuffix(".tg.dev") == true else {
      NSLog("[TelegramAuth][SceneDelegate] skipped: host is not *.tg.dev")
      return
    }

    guard let controller = window?.rootViewController as? FlutterViewController else {
      NSLog("[TelegramAuth][SceneDelegate] ERROR: rootViewController is not FlutterViewController")
      return
    }

    NSLog("[TelegramAuth][SceneDelegate] forwarding to telegram_login plugin via handleUrl")
    FlutterMethodChannel(name: "telegram_login", binaryMessenger: controller.binaryMessenger)
      .invokeMethod("handleUrl", arguments: ["url": url.absoluteString]) { result in
        if let error = result as? FlutterError {
          NSLog("[TelegramAuth][SceneDelegate] handleUrl error: %@ – %@", error.code, error.message ?? "")
        } else {
          NSLog("[TelegramAuth][SceneDelegate] handleUrl success: %@", String(describing: result))
        }
      }
  }
}
