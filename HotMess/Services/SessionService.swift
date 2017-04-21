//
//  SessionService.swift
//  HotMess
//
//  Created by Rick Mark on 1/3/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation
import UIKit
import FacebookCore
import FacebookLogin
import Locksmith



class SessionService {
    let operationQueue = OperationQueue()
    
    static let RSVPEventPermission = "rsvp_event"
    static let UserEventsPermission = "user_events"
    
    private static let sharedInstance = SessionService()
    
    static let loginSuccess = NSNotification.Name("LoginSuccess")
    
    static let accountIdentifier = "social.hotmess.account";
    static let loginRequired = Notification.Name("social.hotmess.loginRequired")
    
    static let loginManager = LoginManager()
    
    static func registerNotifications() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.FBSDKAccessTokenDidChange, object: nil, queue: self.sharedInstance.operationQueue) { (notification) in
            if AccessToken.current != nil {
            
                if let token = AccessToken.current {
                    self.getToken(token: token.authenticationToken, callback: {})
                }
            }
        }
        
        LoginViewController.registerNotifications()
    }
    
    static func logOut() {
        do {
            try Locksmith.deleteDataForUserAccount(userAccount: accountIdentifier)

            SDKSettings.appId = UserDefaults.standard.string(forKey: "facebook_app_id")!
            AccessToken.current = nil
            NotificationCenter.default.post(name: SessionService.loginRequired, object: self)
        }
        catch  {
        }
    }
    
    static var token: String? {
        if let account = Locksmith.loadDataForUserAccount(userAccount: accountIdentifier) {
            if let token = account["token"] as? String {
                return token
            }
        }
        
        return nil
    }
    
    static func getToken(token: String, callback: @escaping () -> Void) {
        
        let deviceToken = UIDevice.current.identifierForVendor?.uuidString
        
        let info = Bundle.main.infoDictionary!
        
        let version = info["CFBundleShortVersionString"] as! String
        let build = info["CFBundleVersion"] as! String
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        
        let parameters = [ "facebook_token" : token,
                           "device" : [
                            "type" : "apple",
                            "identifier" : deviceToken,
                            "version" : version,
                            "build" : build,
                            "model" : identifier ] ] as [ String : Any ]
        
        RequestService.shared.request(relativeUrl: "/token", with: parameters, { (result) in
            if let user = result["user"] as? [ String : Any ] {
                UserService.shared.userId = UUID(uuidString: (user["id"] as! String))!
            }
            
            if let token = result["token"] as? String {
            
                let _ = try? Locksmith.saveData(data: [ "token" : token ], forUserAccount: accountIdentifier)
            
                NotificationCenter.default.post(name: SessionService.loginSuccess, object: self)
                
                UIApplication.shared.registerForRemoteNotifications()
                
                callback()
            }
            else {
                SessionService.logOut()
            }
        })
    }
    
    static func getVersionInfo(callback: @escaping (Int) -> Void) {
        let request = DataRequest("/", parameters: nil) { result in
            let apple = result["client.mobile.apple"] as! [ String : Any ]
            
            callback(apple["minimum_build"] as! Int)
        }
        
        RequestService.shared.request(request)
    }
    
    static func postDeviceToken(_ token: Data) {
        let request = DataRequest("/v1/devices/", parameters: ["device_type": "apple", "vendor_identifier" : UIDevice.current.identifierForVendor!.uuidString, "notification_token" : token.base64EncodedString()]) { result in
            
        }
        
        RequestService.shared.request(request)
    }

    static func ensureHasPermission(_ permission: String, callback: @escaping () -> Void) {
        if AccessToken.current?.grantedPermissions?.contains(Permission(name: permission)) == true {
            callback()
            
            return
        }
        
        SessionService.loginManager.logIn([ ReadPermission.custom(permission) ], viewController: nil) { (result) in

            switch result {
            case let .success(grantedPermissions: _, declinedPermissions: _, token: accessToken):
                SessionService.getToken(token: accessToken.authenticationToken, callback: {
                    callback()
                })
            default:
                break;
            }
        }
    }
    
    static func ensureHasPublishPermission(_ permission: String, callback: @escaping (Void) -> Void) {
        if AccessToken.current?.grantedPermissions?.contains(Permission(name: permission)) == true {
            callback()
            
            return
        }
        
        SessionService.loginManager.logIn([ PublishPermission.custom(permission) ], viewController: nil) { (result) in
            
            switch result {
            case let .success(grantedPermissions: _, declinedPermissions: _, token: accessToken):
                SessionService.getToken(token: accessToken.authenticationToken, callback: {
                    callback()
                })
            default:
                break;
            }
        }
    }
}
