package yool.live.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var pendingTelegramUri: Uri? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "karavantrack_location",
                "KaravanTrack Location Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Running in background to track location"
            }

            val notificationManager: NotificationManager =
                getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }

        // Cold-start: app launched directly by the redirect App Link.
        intent?.data?.takeIf { isTelegramRedirect(it) }?.let { uri ->
            if (!deliverToFlutter(uri)) pendingTelegramUri = uri
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Warm-resume: app was already alive, onNewIntent fires.
        intent.data?.takeIf { isTelegramRedirect(it) }?.let { uri ->
            if (!deliverToFlutter(uri)) pendingTelegramUri = uri
        }
    }

    // Earliest reliable point that flutterEngine is non-null AND the Dart
    // MethodCallHandler registered in TelegramAuthService.init() is live.
    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        pendingTelegramUri?.let { uri ->
            pendingTelegramUri = null
            deliverToFlutter(uri)
        }
    }

    private fun isTelegramRedirect(uri: Uri): Boolean =
        uri.host == "app1451611780-login.tg.dev"

    private fun deliverToFlutter(uri: Uri): Boolean {
        val engine = flutterEngine ?: return false
        val code  = uri.getQueryParameter("code")  ?: return false
        val state = uri.getQueryParameter("state") ?: return false
        MethodChannel(engine.dartExecutor.binaryMessenger, "yool.live.app/telegram_auth")
            .invokeMethod("onTelegramCallback", mapOf("code" to code, "state" to state))
        return true
    }
}
