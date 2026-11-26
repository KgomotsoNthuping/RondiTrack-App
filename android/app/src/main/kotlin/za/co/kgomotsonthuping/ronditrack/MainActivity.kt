package za.co.kgomotsonthuping.ronditrack

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureChannel()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ronditrack/notifications"
        ).setMethodCallHandler { call, result ->
            if (call.method == "ensureChannel") {
                ensureChannel()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "ronditrack_updates",
                "Stokvel updates",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Updates from RondiTrack."
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            }

            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }
}