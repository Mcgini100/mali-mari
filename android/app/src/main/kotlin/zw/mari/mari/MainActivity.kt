package zw.mari.mari

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Android-only capture features to Flutter over "zw.mari/capture":
 *  - text shared to Mari from another app (ACTION_SEND text/plain)
 *  - notification-access status, settings shortcut, filters and the capture queue
 * mari:// deep links are handled by the app_links plugin, not here.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var initialShare: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialShare = sharedText(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val text = sharedText(intent) ?: return
        val ch = channel
        if (ch != null) ch.invokeMethod("onShared", text) else initialShare = text
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zw.mari/capture")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeInitialShare" -> {
                    result.success(initialShare)
                    initialShare = null
                }
                "isListenerEnabled" -> result.success(isListenerEnabled())
                "openListenerSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(null)
                }
                "setFilters" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    val senders = call.argument<List<String>>("senders") ?: emptyList()
                    CaptureStore.setFilters(applicationContext, enabled, packages, senders)
                    result.success(null)
                }
                "drainQueue" -> result.success(CaptureStore.drain(applicationContext))
                else -> result.notImplemented()
            }
        }
    }

    private fun sharedText(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_SEND || intent.type?.startsWith("text/") != true) return null
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
        return if (text.isNullOrEmpty()) null else text
    }

    private fun isListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        val mine = ComponentName(this, MariNotificationListener::class.java)
        return flat.split(":").any { ComponentName.unflattenFromString(it) == mine }
    }
}
