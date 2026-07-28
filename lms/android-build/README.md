# AskEva → Android APK (Capacitor)

This folder is a ready-to-build [Capacitor](https://capacitorjs.com) project that
wraps the AskEva web app in a native Android shell. The whole app is already
bundled into a single offline file at **`www/index.html`** — no server needed.

You run a few commands on your own computer to produce the installable **`.apk`**.

---

## What's in here

```
android-build/
├── www/
│   └── index.html          ← the entire app, self-contained & offline
├── resources/
│   ├── icon.png            ← 1024×1024 app icon (used to generate all sizes)
│   ├── splash.png          ← 2732×2732 launch screen
│   └── splash-dark.png
├── capacitor.config.json   ← app id, name, status-bar + splash settings
├── package.json            ← dependencies + helper scripts
└── README.md               ← you are here
```

App id: `com.tunepath.askeva`  ·  App name: **AskEva**
(Change both in `capacitor.config.json` before your first build if you want a
different package name — it's hard to change later once published.)

---

## 1. Install the prerequisites (one time)

| Tool | Why | Get it |
|---|---|---|
| **Node.js** (LTS) | runs Capacitor's CLI | https://nodejs.org |
| **Android Studio** | gives you the Android SDK, an emulator, and the APK builder | https://developer.android.com/studio |
| **Java JDK 17** | required by the Android Gradle plugin | bundled with recent Android Studio |

After installing Android Studio, open it once and let it finish downloading the
**Android SDK** (Tools → SDK Manager → install the latest "Android SDK Platform"
and "Android SDK Build-Tools").

---

## 2. Build the project (in this folder)

Open a terminal **inside `android-build/`** and run:

```bash
# install dependencies
npm install

# create the native Android project
npx cap add android

# generate launcher icons + splash screens from resources/
npx capacitor-assets generate --android

# copy the web app into the native project
npx cap sync
```

---

## 3. Make the APK

```bash
# open the project in Android Studio
npx cap open android
```

In Android Studio:

1. Wait for Gradle to finish syncing (bottom status bar).
2. Menu → **Build → Build Bundle(s) / APK(s) → Build APK(s)**.
3. When it finishes, click **locate** in the popup — that's your
   `app-debug.apk`. It also lives at:
   `android/app/build/outputs/apk/debug/app-debug.apk`

Copy that file to an Android phone and tap it to install
(you may need to allow "Install unknown apps" for your file manager).

### Prefer the command line?
From `android-build/android/`:
```bash
./gradlew assembleDebug      # macOS / Linux
gradlew.bat assembleDebug    # Windows
```

---

## 4. Release build (for the Play Store)

A debug APK is fine for testing/sideloading but **can't** go on the Play Store.
For a store release you need a **signed App Bundle (.aab)**:

1. In Android Studio: **Build → Generate Signed Bundle / APK → Android App Bundle**.
2. Create a new **keystore** when prompted and **keep it safe** — you need the
   exact same keystore for every future update.
3. Choose the **release** build variant and finish.
4. Upload the resulting `.aab` in the [Play Console](https://play.google.com/console).

---

## Updating the app later

The app lives entirely in `www/index.html`. When you want to ship changes:

1. Replace `www/index.html` with a new bundle.
2. Run `npx cap sync`.
3. Rebuild the APK (step 3) and bump `versionCode` / `versionName` in
   `android/app/build.gradle` for store updates.

---

## Notes & tips

- **Offline by design.** Everything (HTML, CSS, JS, images, fonts) is inlined
  into `www/index.html`, so the app runs with no internet connection.
- **Data storage.** The app saves contacts, groups, settings, etc. in the
  WebView's `localStorage`, which persists between launches on the device.
- **Full-screen.** The desktop "phone frame" mock has been stripped — the app
  fills the whole screen and respects the system status bar and gesture-nav
  insets.
- **Status bar** is brand green with light icons; tweak it in
  `capacitor.config.json` (`plugins.StatusBar`).
- **Hardware back button** closes any open sheet/drawer first, then exits — see
  the small guard injected into the page.
- **No Mac needed** — Android builds run on Windows, macOS, or Linux.

Happy shipping! 🚀
