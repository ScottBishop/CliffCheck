import UIKit
import UserNotifications
import SwiftUI
import Foundation

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else if !granted {
                print("Notification permission not granted")
            }
        }

        // Enable background fetch
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        return true
    }

    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let tideService = TideService()
        
        let workItem = DispatchWorkItem {
            tideService.fetchTideData {
                print("done")
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: workItem)
    }
}
