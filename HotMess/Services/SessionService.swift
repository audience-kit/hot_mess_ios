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
    private static let _sharedInstance = SessionService()
    
    static let LoginSuccess = NSNotification.Name("social.hotmess.loginSuccess")
    static let LoginRequired = Notification.Name("social.hotmess.loginRequired")
    
    static let accountIdentifier = "social.hotmess.account";
    
    static let RSVPEventPermission = "event_rsvp"
    static let UserEventsPermission = "user_events"
    
    static let loginManager = LoginManager()
    
    static var userId: UUID? {
        return _sharedInstance.userId
    }
    
    var userId: UUID?
    
    init() {
        NotificationCenter.default.addObserver(forName: Notification.Name.FBSDKAccessTokenDidChange, object: nil, queue: OperationQueue.main) { (notification) in
            DispatchQueue.global().async {
                SessionService.ensureSession()
            }
        }
    }
    
    static func ensureSession() {
        if let credential = AccessToken.current {
            self.getToken(token: credential.authenticationToken, callback: { (result) in
                if result {
                    NotificationCenter.default.post(name: SessionService.LoginSuccess, object: nil)
                }
            })
        }
        else {
            NotificationCenter.default.post(name: SessionService.LoginRequired, object: nil)
        }
    }
    
    static func logOut() {
        do {
            try Locksmith.deleteDataForUserAccount(userAccount: accountIdentifier)
            NotificationCenter.default.post(name: SessionService.LoginRequired, object: nil)
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
    
    static func getToken(token: String, callback: @escaping (Bool) -> Void) {
        
        let parameters = [ "facebook_token" : token,
                           "device" : [
                            "type" : "apple",
                            "identifier" : DeviceService.deviceToken,
                            "version" : DeviceService.applicationVersion,
                            "build" : DeviceService.applicationBuild,
                            "model" : DeviceService.deviceModel] ] as [ String : Any ]
        
        let request = DataRequest("/v1/token", parameters: parameters) { (result) in
            if let user = result["user"] as? [ String : Any ] {
                _sharedInstance.userId = UUID(uuidString: (user["id"] as! String))!
            }
            
            if let token = result["token"] as? String {
            
                let _ = try? Locksmith.saveData(data: [ "token" : token ], forUserAccount: accountIdentifier)
            
                NotificationCenter.default.post(name: SessionService.LoginSuccess, object: nil)
                
                UIApplication.shared.registerForRemoteNotifications()
                
                callback(true)
                return
            }
            else {
                SessionService.logOut()
            }
            callback(false)
        }
        
        request.operationQueue = DispatchQueue.global()
        
        RequestService.shared.request(request)
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
                SessionService.getToken(token: accessToken.authenticationToken, callback: { (result) in
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
                SessionService.getToken(token: accessToken.authenticationToken, callback: { (result) in
                    callback()
                })
            default:
                break;
            }
        }
    }
    
    static func me(callback: @escaping (User) -> Void) {
        RequestService.shared.request(relativeUrl: "/v1/me") { (result: [String : Any]) in
            if result["id"] != nil {
                let user = User(result)
                _sharedInstance.userId = user.id
                callback(user)
            }
        }
    }
}
