package zw.mari.mari

import android.app.Notification
import android.os.Build
import android.os.Bundle
import android.os.Parcelable
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Reads the text of notifications Android is already showing — never the SMS
 * inbox. Everything that fails the person's filters is ignored on the spot
 * and never stored:
 *  1. capture must be switched on in Mari,
 *  2. the posting app must be one the person ticked,
 *  3. for messaging apps, the sender (notification title) must match a listed name,
 *  4. the text must mention a currency and a number.
 * What passes is queued on-device for the Flutter side to parse and show for review.
 */
class MariNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        try {
            handle(sbn)
        } catch (e: Throwable) {
            // A malformed notification must never crash the listener.
        }
    }

    private fun handle(sbn: StatusBarNotification) {
        val ctx = applicationContext
        if (!CaptureStore.isEnabled(ctx)) return

        val pkg = sbn.packageName ?: return
        if (pkg == packageName) return
        if (pkg !in CaptureStore.packages(ctx)) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()

        if (pkg in CaptureStore.messagingPackages) {
            val senders = CaptureStore.senders(ctx)
            if (senders.none { title.contains(it, ignoreCase = true) }) return
        }

        val text = latestMessageText(extras)
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: return

        if (!CaptureStore.looksFinancial(text)) return

        CaptureStore.enqueue(ctx, text, pkg, title, sbn.postTime)
    }

    /** Messaging apps put the newest message last in EXTRA_MESSAGES. */
    private fun latestMessageText(extras: Bundle): String? {
        val messages: Array<Parcelable>? = if (Build.VERSION.SDK_INT >= 33) {
            extras.getParcelableArray(Notification.EXTRA_MESSAGES, Parcelable::class.java)
        } else {
            @Suppress("DEPRECATION")
            extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        }
        val last = messages?.lastOrNull() as? Bundle ?: return null
        return last.getCharSequence("text")?.toString()
    }
}
