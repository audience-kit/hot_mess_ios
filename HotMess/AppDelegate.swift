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
import Kingfisher
import UserNotifications
import Mixpanel
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var mixpanel: Mixpanel?
    
    static let facebookAppIdIdentifier = "FacebookAppID"
    static let mixpanelAPIKey = "MixpanelAPIKey"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Fabric.with([Crashlytics.self])

        SDKSettings.appId = Bundle.main.infoDictionary![AppDelegate.facebookAppIdIdentifier] as! String
        
        AppEventsLogger.activate()
        
        self.mixpanel = Mixpanel.sharedInstance(withToken: Bundle.main.infoDictionary![AppDelegate.mixpanelAPIKey] as! String)
        
        // Override point for customization after application launch.
        SDKApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        LoginViewController.registerForLogin()
        LocationService.shared.start()
        
        SessionService.getVersionInfo { versionInfo in
            let build = Int(Bundle.main.infoDictionary!["CFBundleVersion"] as! String)
            
            if build! < versionInfo.minimumBuild {
                DispatchQueue.main.async {
                    let source = VersionInfo.isTestFlight ? "TestFlight" : "the App Store"
                    let updateAlert = UIAlertController(title: "Update Required", message: "You must update to version \(versionInfo.minimumVersion) in \(source) before you can continue to use this app.", preferredStyle: .alert)
                    updateAlert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: { action in
                        
                    }))
                    
                    self.window!.rootViewController!.present(updateAlert, animated: true, completion: nil)
                }
            }
            else {
                SessionService.ensureSession()
            }
        }
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        SessionService.postDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error){
        NSLog(error.localizedDescription)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        LocationService.shared.stop()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        LocationService.shared.start()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        let handled = SDKApplicationDelegate.shared.application(app, open: url, options: options)
        
        return handled
    }
}

