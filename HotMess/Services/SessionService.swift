//
//  SessionService.swift
//  HotMess
//
//  Created by Rick Mark on 1/3/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation
import UIKit
import FBSDKLoginKit

class SessionService {
    public static let tokenNotification: Notification.Name = Notification.Name(rawValue: "SessionService.tokenNotification")
    public static let loginNotification: Notification.Name = Notification.Name(rawValue: "SessionService.loginNotification")
    public static let logoutNotification: Notification.Name = Notification.Name(rawValue: "SessionService.logoutNotification")
    
    private static var _sharedInstance: SessionService?
    
    static var sharedInstance: SessionService {
        if (_sharedInstance == nil)
        {
            _sharedInstance = SessionService()
        }
        
        return _sharedInstance!
    }
    
    static func registerNotifications() {
        NotificationCenter.default.addObserver(forName: nil, object: nil, queue: sharedInstance.operationQueue) { notification in
            switch (notification.name) {
            case tokenNotification:
                let token = notification.userInfo?["token"] as! FBSDKAccessToken
                RequestService.sharedInstance.request(relativeUrl: "/token", with: ["token": token]) { result in
                    
                }
            default:
                break;
            }
        }
    }
    
    let operationQueue = OperationQueue()
    
    
}
