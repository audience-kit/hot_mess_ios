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

class LoginViewController : UIViewController, FBSDKLoginButtonDelegate {
    private static let shared = LoginViewController(nibName: "LoginView", bundle: Bundle.main)
    
    
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
            
            LoginViewController.present() {
                if shared.alertController.presentingViewController == nil {
                    shared.present(shared.alertController, animated: true, completion: nil)
                }
            }
        }
        NotificationCenter.default.addObserver(forName: SessionService.LoginSuccess, object: nil, queue: OperationQueue.main) { (notification) in
            LoginViewController.dismiss()
        }
    }
    
    let alertController: UIAlertController
    
    @IBOutlet var loginButton: FBSDKLoginButton?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {        
        self.alertController = UIAlertController(title: "Login Error", message: "Something went wrong while attempting to log you in.", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Retry", style: .default, handler: { action in
            AccessToken.current = nil
            
            DispatchQueue.global().async {
                SessionService.ensureSession()
            }
        }))

        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.alertController = UIAlertController(title: "Login Error", message: "Something went wrong while attempting to log you in.", preferredStyle: .alert)
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
        
        loginButton?.publishPermissions = [ "rsvp_event" ]
        loginButton?.readPermissions = SessionService.ReadPermissions
        
        loginButton?.delegate = self
    }
    
    public func loginButton(_ loginButton: FBSDKLoginButton!, didCompleteWith result: FBSDKLoginManagerLoginResult!, error: Error!) {
        if result.token != nil {
            SessionService.ensureSession()
        }
    }
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {
        
    }
    
}

