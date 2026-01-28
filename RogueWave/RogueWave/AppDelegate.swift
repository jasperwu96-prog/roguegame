//
//  AppDelegate.swift
//  RogueWave
//
//  A real-time top-down roguelike wave survival game
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Create window programmatically for iOS 13+
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = GameViewController()
        window?.makeKeyAndVisible()

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Pause the game when app becomes inactive
        NotificationCenter.default.post(name: .gameShouldPause, object: nil)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Save game state when entering background
        GameManager.shared.saveProgress()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Resume game when returning to foreground
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Resume the game
        NotificationCenter.default.post(name: .gameShouldResume, object: nil)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let gameShouldPause = Notification.Name("gameShouldPause")
    static let gameShouldResume = Notification.Name("gameShouldResume")
}
