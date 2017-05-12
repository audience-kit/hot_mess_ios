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
    private static let _sharedInstance = LoginViewController(nibName: "LoginView", bundle: Bundle.main)
    
    public static var shared : LoginViewController {
        return _sharedInstance
    }
    
    public static func present() {
        if _sharedInstance.isBeingPresented == false && AccessToken.current == nil {
            UIApplication.shared.keyWindow!.rootViewController!.present(_sharedInstance, animated: true, completion: nil)
        }
    }
    
    public static func registerForLogin() {
        NotificationCenter.default.addObserver(forName: SessionService.LoginRequired, object: nil, queue: OperationQueue.main) { (notification) in
            DispatchQueue.main.async {
                LoginViewController.present()
            }
        }
        NotificationCenter.default.addObserver(forName: SessionService.LoginFailed, object: nil, queue: OperationQueue.main) { notification in
            SessionService.logOut()
            
            DispatchQueue.main.async {
                if shared.parent != nil && shared.alertController.parent == nil {
                    shared.present(shared.alertController, animated: true)
                }
                else {
                    UIApplication.shared.keyWindow!.rootViewController!.present(shared, animated: true, completion: {
                        DispatchQueue.main.async {
                            if shared.alertController.parent == nil {
                                shared.present(shared.alertController, animated: true)
                            }
                        }
                    })
                }
            }
        }

    }
    
    @IBOutlet var loginButton: FBSDKLoginButton?
    private let alertController: UIAlertController = {
        let controller = UIAlertController(title: "Login Error", message: "Something went wrong while attempting to log you in.", preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Retry", style: .default, handler: { action in
            DispatchQueue.global().async {
                SessionService.ensureSession()
            }
        }))
        return controller
    }()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        self.registerLogin()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.registerLogin()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loginButton?.publishPermissions = [ "rsvp_event" ]
        loginButton?.readPermissions = SessionService.ReadPermissions
        
        loginButton?.delegate = self

        DispatchQueue.global().async {
            SessionService.ensureSession()
        }
    }
    
    public func loginButton(_ loginButton: FBSDKLoginButton!, didCompleteWith result: FBSDKLoginManagerLoginResult!, error: Error!) {
        if result.token != nil {
            SessionService.ensureSession()
        }
    }
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {
        
    }
    
    private func registerLogin() {
        NotificationCenter.default.addObserver(forName: SessionService.LoginSuccess, object: nil, queue: OperationQueue.main) { (notification) in
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
}

