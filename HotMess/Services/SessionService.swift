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
    private static let sharedInstance = SessionService()
    
    static func registerNotifications() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.FBSDKAccessTokenDidChange, object: nil, queue: self.sharedInstance.operationQueue) { (notification) in
            if (AccessToken.current == nil) { return }
            
            let deviceToken = UIDevice.current.identifierForVendor?.uuidString
            
            let parameters = ["facebook_token": AccessToken.current!.authenticationToken, "apple_device_identifier": deviceToken]
            
            RequestService.sharedInstance.request(relativeUrl: "/token", with: parameters, { (result) in
                
                let token = result["token"] as! String
                
                let _ = try? Locksmith.saveData(data: ["token" : token], forUserAccount: "social.hotmess.account")

            })
        }
    }

    let operationQueue = OperationQueue()
}
