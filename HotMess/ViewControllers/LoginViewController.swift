//
//  HeroViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/3/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FacebookLogin
import FBSDKLoginKit

class LoginViewController : UIViewController {
    @IBOutlet var loginButton: FBSDKLoginButton?
    
    static func registerNotifications() {
        NotificationCenter.default.addObserver(forName: SessionService.loginRequired, object: nil, queue: OperationQueue.main) { (notification) in
            let rootViewController = UIApplication.shared.keyWindow?.rootViewController!

            let loginViewController = LoginViewController(nibName: "LoginView", bundle: Bundle.main)

            rootViewController?.present(loginViewController, animated: true, completion: { })
        }
        

    
    }
    
    override func awakeFromNib() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.FBSDKAccessTokenDidChange, object: self, queue: OperationQueue.main) { notification in
            self.dismiss()
        }
    }

    override func viewDidLoad() {
        // TODO: user_likes scope when approved
        self.loginButton!.readPermissions = [ "email", "public_profile", "user_friends", "user_likes", "user_events" ]
        self.loginButton!.publishPermissions = [ "rsvp_event" ]
        
        NotificationCenter.default.addObserver(forName: Notification.Name.FBSDKAccessTokenDidChange, object: nil, queue: OperationQueue.main) { (notification) in
            self.dismiss()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if FBSDKAccessToken.current() != nil {
            self.dismiss()
        }
    }
    
    func dismiss() {
        if FBSDKAccessToken.current() != nil {
            DispatchQueue.global().async {
                SessionService.getToken(token: FBSDKAccessToken.current().tokenString!, callback: {
                    LocationService.shared.closest(callback: { (locale) in
                        DispatchQueue.main.async {
                            self.dismiss(animated: true, completion: {
                                NotificationCenter.default.post(name: Notification.Name.FBSDKAccessTokenDidChange, object: self)
                            })
                        }
                    })
                })
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

