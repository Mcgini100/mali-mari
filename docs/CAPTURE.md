# Capturing EcoCash and bank messages

## What each platform allows

**iPhone.** No third-party app can read SMS, iMessage or other apps' notifications. There is no permission for it. Mari offers three routes instead: paste in Review, and a personal **Shortcuts automation** that hands each matching text to Mari through a deep link.

**Android.** Google Play treats `READ_SMS` and `RECEIVE_SMS` as restricted permissions, approved only for apps whose core function is SMS (the default SMS app and a few exceptions). A budgeting app does not qualify, so **Mari does not request them**. Instead it uses notification access (`NotificationListenerService`), which reads the text of notifications the phone is already showing, only after the person turns it on in system settings.

## Android notification capture

1. Settings → Read money alerts opens Mari's consent screen (`lib/features/settings/consent_screen.dart`), which explains what is and isn't read and lets the person pick apps and SMS sender names.
2. Their choices are pushed to native code (`setFilters`) and stored in `SharedPreferences`.
3. Android's own Notification access screen opens; the person switches Mari on.
4. `MariNotificationListener.kt` drops every notification that fails any filter, without storing it:
   capture enabled → app is one the person ticked → for Messages apps, the sender name matches the list → the text mentions a currency and a number.
5. What passes is queued on-device. Flutter drains the queue on launch, on resume and every 5 s while open, parses each item, discards low-confidence ones (promotions), de-duplicates, and stores the rest as **pending** entries for Review.

### Sideloaded test builds

Google Play Protect's fraud protection blocks apps installed outside the Play Store (from a browser, WhatsApp or a file manager) that request notification access, the same as SMS access. That's why CI also builds `mari-sideload-apk`, which removes the listener from the manifest (`android/app/src/profile/AndroidManifest.xml`). The app checks at runtime (`isListenerAvailable`) and shows "Not in this test build" in Settings. To test alert reading itself, install `mari-full-apk` with `adb install`, or publish to a Play Console internal-testing track.

### Play Console declarations

- **Permissions declaration:** none needed for SMS (not requested).
- **Notification listener:** Google may ask, through policy review, why the app uses `BIND_NOTIFICATION_LISTENER_SERVICE`. Suggested answer: "Optional, user-enabled feature that reads transaction alerts from mobile-money and banking apps the user selects, to pre-fill expense entries that the user reviews and confirms. Other notifications are ignored and never stored. Data never leaves the device."
- **Data safety form:** collected data = none (all data stays on device; nothing is transmitted). Financial info is *processed on device* only.
- Include a short video of the consent screen and the Review step in the review notes.

### Package names to verify

`lib/app/settings.dart → CaptureDefaults` lists `com.ecocash.superapp` and `com.ecocash` (EcoCash), `com.google.android.apps.messaging` (Google Messages) and `com.samsung.android.messaging` (Samsung Messages). Check the EcoCash ids against the current Play Store listing before release, and add OneMoney or bank apps the same way once their package names are confirmed.

## iPhone: Shortcuts automation

The in-app guide is `lib/features/settings/shortcut_guide_screen.dart`. In short:

1. Shortcuts → Automation → New Automation → **Message**.
2. Sender: EcoCash (add bank senders too). Choose **Run Immediately**.
3. Actions: **URL Encode** (input: Shortcut Input / message content) → **Text** `mari://capture?text=` followed by the encoded text → **Open URLs**.

Each text opens Mari with the entry waiting in Review. Requirements: iOS 17 or later for Message automations that run without asking. `tool/setup.sh` registers the `mari` URL scheme in `Info.plist`; if you set up iOS by hand, add:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key><string>zw.mari.capture</string>
    <key>CFBundleURLSchemes</key><array><string>mari</string></array>
  </dict>
</array>
<key>FlutterDeepLinkingEnabled</key><false/>
```

## Testing capture without a phone full of alerts

- Paste any fixture from `test/fixtures/messages.json` into Review.
- Android: `adb shell am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT "You have received ZiG150.00 from TATENDA MOYO." zw.mari.mari`
- Deep link: `adb shell am start -a android.intent.action.VIEW -d "mari://capture?text=Payment%20of%20USD12.50%20to%20SPAR%20successful."`
- iOS simulator: `xcrun simctl openurl booted "mari://capture?text=Payment%20of%20USD12.50%20to%20SPAR%20successful."`
