package yool.live.app

import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var pendingTelegramUri: Uri? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // The 1.x tracker's notification channel ("KaravanTrack Location
        // Service") survives an app update; the tracking library brings its
        // own, so drop the old one from the app's notification settings.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java)
                .deleteNotificationChannel("karavantrack_location")
        }

        // Cold-start: app launched by the redirect App Link.
        // Do NOT call deliverToFlutter() here. flutterEngine is non-null after
        // super.onCreate(), but the Dart isolate is still initialising —
        // TelegramAuthService.init() has not registered the MethodChannel
        // handler yet, so invokeMethod() would silently drop the message.
        // Delivery is deferred to onFlutterUiDisplayed(), which fires only
        // after the first Flutter frame (and therefore after initState has
        // registered the handler).
        intent?.data?.takeIf { isTelegramRedirect(it) }?.let { uri ->
            pendingTelegramUri = uri
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The system location toggle, for the "GPS is off" overlay.
        // permission_handler can only open the app's own settings page.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yool.live.app/settings")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openLocationSettings" -> {
                        startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // Telegram's login domain this build was made for (build.gradle.kts).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yool.live.app/telegram_auth")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "loginHost" -> result.success(getString(R.string.telegram_login_host))
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Warm-resume: Dart handler already registered, try immediate delivery.
        intent.data?.takeIf { isTelegramRedirect(it) }?.let { uri ->
            if (!deliverToFlutter(uri)) pendingTelegramUri = uri
        }
    }

    // Fired after the first Flutter frame — Dart handler is guaranteed live.
    // Drains any URI that was stashed during cold-start onCreate().
    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        pendingTelegramUri?.let { uri ->
            pendingTelegramUri = null
            deliverToFlutter(uri)
        }
    }

    // Safety-net for the warm-resume case: if onNewIntent ran but
    // deliverToFlutter failed (engine briefly null), retry here.
    override fun onResume() {
        super.onResume()
        pendingTelegramUri?.let { uri ->
            if (deliverToFlutter(uri)) pendingTelegramUri = null
        }
    }

    private fun isTelegramRedirect(uri: Uri): Boolean =
        uri.scheme == "yoollive" && uri.host == "tglogin"

    private fun deliverToFlutter(uri: Uri): Boolean {
        val engine = flutterEngine ?: return false
        val code  = uri.getQueryParameter("code")  ?: return false
        val state = uri.getQueryParameter("state") ?: return false
        MethodChannel(engine.dartExecutor.binaryMessenger, "yool.live.app/telegram_auth")
            .invokeMethod("onTelegramCallback", mapOf("code" to code, "state" to state))
        return true
    }
}
