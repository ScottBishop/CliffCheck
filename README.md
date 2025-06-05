# CliffCheck

CliffCheck is an iOS app that alerts you when beach tide conditions are favorable.

It includes:

* Tide threshold alerts
* Time to sunset
* Push notification alerts for favorable tide conditions

---

## 📱 iOS App

### Requirements

* Xcode 15+
* Swift 5.9+
* iOS 16+
* A valid Apple Developer account for push notifications

### Setup

1. Clone the repo:

   ```bash
   git clone https://github.com/scottbishop/cliffcheck.git
   cd cliffcheck
   ```

2. Open the project in Xcode:

   ```bash
   open CliffCheck.xcodeproj
   ```

3. Configure push notifications:

   * Enable **Push Notifications** and **Background Modes → Remote Notifications** in Signing & Capabilities
   * Ensure your provisioning profile has the `aps-environment` entitlement

4. Add Secrets.plist in /CliffCheck which should contain `WorldTidesAPIKey=abc123`

5. Add GoogleService-Info.plist in /CliffCheckfrom which can be found in your firebase project that enables FCM, Crashlytics, and Analytics. 

6. Build and run on device or simulator

---

## ☁️ Firebase Functions

Tide alerts are sent via Firebase Cloud Functions on a daily schedule using the WorldTides API to a FCM notifications topic.

### Structure

* Functions are located in the `/functions` directory
* `sendTideAlert` is scheduled for **6:00 AM PT daily** using `onSchedule`

### Requirements

* Node.js 22
* Firebase CLI
* Firebase project already initialized

### One-time setup

```bash
cd functions
npm install
```

### Set your WorldTides API key securely

```bash
firebase functions:config:set worldtides.key="YOUR_API_KEY"
```

Confirm with:

```bash
firebase functions:config:get
```

---

### Deploy

From the functions directory:

```bash
cd functions
firebase deploy --only functions
```

---

## 🔔 Push Notification Topics

Users are subscribed to the `tide-updates` topic. Notifications are sent if the tide drops below a configured threshold for a given beach.

---

## 🛠️ Future Enhancements

* Add more beaches
* Customize alert thresholds per user
* iOS widget for the homescreen

---

## 👨‍💼 Author

Made with ☕ and ocean stoke by [Scott Bishop](https://github.com/scottbishop)

---

## 📝 License

Apache 2.0 License — free to use, modify, and share.
