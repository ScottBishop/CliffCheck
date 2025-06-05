import UIKit
import UserNotifications
import SwiftUI
import Foundation
import FirebaseCore
import FirebaseMessaging
import FirebaseAnalytics
import FirebaseCrashlytics

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
        
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else if !granted {
                print("Notification permission not granted")
            } else {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("Registered for remote FCM notifications")

                }
            }
        }

        // Enable background fetch
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Receiving APN token...")
        // 1. Set the APNs token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📦 APNs token received and set: \(tokenString)")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let tideService = TideService()
        
        let workItem = DispatchWorkItem {
            tideService.fetchTideData {
                print("Background fetch completed")
                completionHandler(.newData)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: workItem)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Receiving FCM token...")

        guard let fcmToken = fcmToken else {
            print("⚠️ FCM token is nil, cannot subscribe to topic.")
            return
        }
        print("📬 Received FCM token: \(fcmToken)")
        
        // ✅ Subscribe to topic after receiving valid FCM token
        Messaging.messaging().subscribe(toTopic: "tide-updates") { error in
            if let error = error {
                print("❌ Failed to subscribe to topic: \(error.localizedDescription)")
            } else {
                print("✅ Subscribed to tide-updates topic")
                Analytics.logEvent("subscribed_to_tide_updates", parameters: [
                    "method": "fcm_topic"
                ])
            }
        }
    }
}
