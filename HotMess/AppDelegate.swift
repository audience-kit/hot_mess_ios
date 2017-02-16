//
//  AppDelegate.swift
//  HotMess
//
//  Created by Rick Mark on 1/2/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FacebookCore
import FacebookLogin

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    static let serverBaseIdentifier = "HotMessServerBase"
    static let newRelicIdentifier = "NewRelicIdentifier"
    static let beaconIdentifier = "social.hotmess.beacon"
    
    public static let defaultBaseUrl = Bundle.main.infoDictionary?[serverBaseIdentifier] as! String
    
    static var baseUrl : URL {
        if let serverUrl = UserDefaults.standard.string(forKey: "server_url") {
            return URL(string: serverUrl)!
        }
        
        return URL(string: AppDelegate.defaultBaseUrl)!
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        NewRelicAgent.start(withApplicationToken: Bundle.main.infoDictionary?[AppDelegate.newRelicIdentifier] as! String)
        
        UserDefaults.standard.register(defaults: ["server_url": AppDelegate.defaultBaseUrl, "facebook_app_id": "713525445368431"])
        
        SDKSettings.appId = UserDefaults.standard.string(forKey: "facebook_app_id")!
        
        // Override point for customization after application launch.
        SDKApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        LocaleService.shared.start()
        
        SessionService.registerNotifications()
        
        //NotificationCenter.default.post(name: Notification.Name.FBSDKAccessTokenDidChange, object: self, userInfo: nil)
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return SDKApplicationDelegate.shared.application(app, open: url, options: options)
    }
}

