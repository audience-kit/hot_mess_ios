//
//  HeroViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/3/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FacebookLogin
import FacebookCore
import FBSDKLoginKit

class LoginViewController : UIViewController {
    private static let shared = LoginViewController(nibName: "LoginView", bundle: Bundle.main)
    
    private static let requiredRead: Set<String> = [ "user_events", "user_likes", "email", "user_friends", "public_profile" ]
    private static let requiredReadPermission: Set<Permission> = [ "user_events", "user_likes", "email", "user_friends", "public_profile" ]
    
    public static func present(completion callback: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            if shared.presentingViewController == nil  {
                UIApplication.shared.keyWindow!.rootViewController!.present(shared, animated: true, completion: callback)
            }
            else {
                if callback != nil { callback!() }
            }
        }
    }
    
    public static func dismiss(callback: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            if shared.presentingViewController != nil {
                shared.dismiss(animated: true, completion: callback)
            }
        }
    }
    
    public static func registerForLogin() {
        NotificationCenter.default.addObserver(forName: SessionService.LoginRequired, object: nil, queue: OperationQueue.main) { (notification) in
            LoginViewController.present()
        }
        NotificationCenter.default.addObserver(forName: SessionService.LoginFailed, object: nil, queue: OperationQueue.main) { notification in
            SessionService.logOut()
            AccessToken.current = nil
            shared.loginButton?.readPermissions = Array<String>(requiredRead)
            
            LoginViewController.present() {
                if shared.alertController.presentingViewController == nil {
                    shared.present(shared.alertController, animated: true, completion: nil)
                }
            }
        }
        NotificationCenter.default.addObserver(forName: SessionService.LoginSuccess, object: nil, queue: OperationQueue.main) { (notification) in
            LoginViewController.dismiss()
        }
        NotificationCenter.default.addObserver(forName: Notification.Name.FBSDKAccessTokenDidChange, object: nil, queue: OperationQueue.main) { notification in
            if AccessToken.current == nil {
                NotificationCenter.default.post(name: SessionService.LoginFailed, object: nil)
                return
            }
            
            if AccessToken.current!.grantedPermissions?.isSuperset(of: LoginViewController.requiredReadPermission) == false {
                SessionService.ensureHasPermission([String](LoginViewController.requiredRead)) {
                    SessionService.ensureSession()
                }
            }
            else {
                SessionService.ensureSession()
            }
        }
    }
    
    let alertController: UIAlertController
    
    @IBOutlet var loginButton: FBSDKLoginButton?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {        
        self.alertController = UIAlertController(title: "Login Error", message: "Something went wrong while attempting to log you in. Ensure you granted the required Facebook permissions.", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Retry", style: .default, handler: { action in
            AccessToken.current = nil
            
            DispatchQueue.global().async {
                SessionService.ensureSession()
            }
        }))

        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.alertController = UIAlertController(title: "Login Error", message: "Something went wrong while attempting to log you in. Ensure you granted the required Facebook permissions.", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Retry", style: .default, handler: { action in
            AccessToken.current = nil
            
            DispatchQueue.global().async {
                SessionService.ensureSession()
            }
        }))
        
        super.init(coder: aDecoder)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loginButton!.readPermissions = Array<String>(LoginViewController.requiredRead)
    }
}

