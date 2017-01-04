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
    static let tokenNotification: Notification.Name = Notification.Name(rawValue: "SessionService.tokenNotification")
    
    private static var _sharedInstance: SessionService?
    
    static var sharedInstance: SessionService {
        if (_sharedInstance == nil)
        {
            _sharedInstance = SessionService()
        }
        
        return _sharedInstance!
    }
    
    static func registerNotifications() {
        NotificationCenter.default.addObserver(forName: nil, object: self, queue: sharedInstance.operationQueue) { notification in
            switch (notification.name) {
            case tokenNotification:
                break;
            default:
                break;
            }
        }
    }
    
    let operationQueue = OperationQueue()
}
