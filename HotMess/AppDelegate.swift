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
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var mixpanel: Mixpanel?
    
    static let facebookAppIdIdentifier = "FacebookAppID"
    static let mixpanelAPIKey = "MixpanelAPIKey"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()

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
    
    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    static var rootViewController: UIViewController? {
        return AppDelegate.shared.window!.rootViewController
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
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            let id = UUID(uuidString: userActivity.webpageURL!.pathComponents[2])!
            let type = userActivity.webpageURL!.pathComponents[1]
            
            self.openItemType(type, id: id)
            
            return true
        }
        
        return false
    }
    
    func openItemType(_ type: String, id: UUID) {
        let tabController = window!.rootViewController as! UITabBarController
        
        if type == "venues" {
            let venueListController = tabController.viewControllers![2] as! UINavigationController
            
            DataService.shared.venue(id, callback: { venue in
                DispatchQueue.main.async {
                    let venueViewController = venueListController.storyboard!.instantiateViewController(withIdentifier: "venue") as! VenueViewController
                    venueViewController.venue = venue
                    venueListController.popToRootViewController(animated: false)
                    tabController.selectedViewController = venueListController
                    venueListController.pushViewController(venueViewController, animated: true)
                }
            })
        }
        if type == "events" {
            let eventListController = tabController.viewControllers![1] as! UINavigationController
            
            DataService.shared.event(id, callback: { event in
                DispatchQueue.main.async {
                    let eventViewController = eventListController.storyboard!.instantiateViewController(withIdentifier: "event") as! EventViewController
                    eventViewController.event = event
                    eventListController.popToRootViewController(animated: false)
                    tabController.selectedViewController = eventListController
                    eventListController.pushViewController(eventViewController, animated: true)
                }
            })
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        var handled = SDKApplicationDelegate.shared.application(app, open: url, options: options)
        
        if handled == false && url.scheme == "hotmess" {
            let id = UUID(uuidString: url.pathComponents[1])!
            let type = url.host!
            
            self.openItemType(type, id: id)
            
            handled = true
        }
        
        return handled
    }
}

