package zw.mari.mari

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persists the person's capture choices and a small queue of notifications
 * that passed the filters, so nothing is lost while Mari isn't running.
 * The Flutter side drains the queue and turns each item into a transaction
 * awaiting review. Nothing here ever leaves the device.
 */
object CaptureStore {
    private const val PREFS = "mari_capture"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_PACKAGES = "packages"
    private const val KEY_SENDERS = "senders"
    private const val KEY_QUEUE = "queue"
    private const val MAX_QUEUE = 200

    /** Messaging apps: only texts whose sender matches a listed name are kept. */
    val messagingPackages = setOf(
        "com.google.android.apps.messaging",
        "com.samsung.android.messaging",
    )

    private val moneyPattern = Regex("(?i)(zig|zwg|usd|us\\$|\\$)\\s?\\d")

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun setFilters(context: Context, enabled: Boolean, packages: List<String>, senders: List<String>) {
        prefs(context).edit()
            .putBoolean(KEY_ENABLED, enabled)
            .putStringSet(KEY_PACKAGES, packages.toSet())
            .putStringSet(KEY_SENDERS, senders.toSet())
            .apply()
        if (!enabled) clearQueue(context)
    }

    fun isEnabled(context: Context): Boolean = prefs(context).getBoolean(KEY_ENABLED, false)

    fun packages(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_PACKAGES, emptySet()) ?: emptySet()

    fun senders(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_SENDERS, emptySet()) ?: emptySet()

    /** Cheap first gate: does the text mention a currency followed by a number? */
    fun looksFinancial(text: String): Boolean = moneyPattern.containsMatchIn(text)

    @Synchronized
    fun enqueue(context: Context, text: String, packageName: String, title: String, postedAt: Long) {
        val p = prefs(context)
        val queue = JSONArray(p.getString(KEY_QUEUE, "[]"))
        // Same notification re-posted (updates, re-alerts): keep one copy.
        for (i in 0 until queue.length()) {
            val o = queue.getJSONObject(i)
            if (o.optString("text") == text && o.optString("package") == packageName) return
        }
        queue.put(
            JSONObject()
                .put("text", text)
                .put("package", packageName)
                .put("title", title)
                .put("postedAt", postedAt)
        )
        val trimmed = JSONArray()
        val start = maxOf(0, queue.length() - MAX_QUEUE)
        for (i in start until queue.length()) trimmed.put(queue.get(i))
        p.edit().putString(KEY_QUEUE, trimmed.toString()).apply()
    }

    @Synchronized
    fun drain(context: Context): List<Map<String, Any>> {
        val p = prefs(context)
        val queue = JSONArray(p.getString(KEY_QUEUE, "[]"))
        val out = ArrayList<Map<String, Any>>(queue.length())
        for (i in 0 until queue.length()) {
            val o = queue.getJSONObject(i)
            out.add(
                mapOf(
                    "text" to o.optString("text"),
                    "package" to o.optString("package"),
                    "title" to o.optString("title"),
                    "postedAt" to o.optLong("postedAt"),
                )
            )
        }
        p.edit().putString(KEY_QUEUE, "[]").apply()
        return out
    }

    @Synchronized
    fun clearQueue(context: Context) {
        prefs(context).edit().putString(KEY_QUEUE, "[]").apply()
    }
}
