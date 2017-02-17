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
    
    static let accountIdentifier = "social.hotmess.account";
    static let loginRequired = Notification.Name("social.hotmess.loginRequired")
    
    static func registerNotifications() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.FBSDKAccessTokenDidChange, object: nil, queue: self.sharedInstance.operationQueue) { (notification) in
            if AccessToken.current != nil {
            
                self.getToken(token: (AccessToken.current?.authenticationToken)!, callback: { 
                
                })
            }
        }
        
        LoginViewController.registerNotifications()
    }
    
    static func logOut() {
        do {
            try Locksmith.deleteDataForUserAccount(userAccount: accountIdentifier)
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
        
        let parameters = [ "facebook_token" : token, "device" : ["type" : "apple", "identifier" : deviceToken ] ] as [ String : Any ]
        
        RequestService.sharedInstance.request(relativeUrl: "/token", with: parameters, { (result) in
            
            let token = result["token"] as! String
            
            let _ = try? Locksmith.saveData(data: [ "token" : token ], forUserAccount: accountIdentifier)
            
            callback()
        })
    }

    let operationQueue = OperationQueue()
}
