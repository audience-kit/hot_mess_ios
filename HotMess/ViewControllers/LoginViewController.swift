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
    private static var _window : UIWindow?
    private static let _sharedInstance = LoginViewController(nibName: "LoginView", bundle: Bundle.main)
    
    public static var shared : LoginViewController {
        return _sharedInstance
    }
    
    public static func present() {
        if _sharedInstance.isBeingPresented == false {
            _window!.rootViewController!.present(_sharedInstance, animated: true, completion: nil)
        }
    }
    
    public static func registerForLogin(_ window: UIWindow) {
        _window = window
        NotificationCenter.default.addObserver(forName: SessionService.LoginRequired, object: nil, queue: OperationQueue.main) { (notification) in
            DispatchQueue.main.async {
                LoginViewController.present()
            }
        }
    }
    
    @IBOutlet var loginButton: FBSDKLoginButton?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        self.registerLoginSuccess()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.registerLoginSuccess()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func registerLoginSuccess() {
        NotificationCenter.default.addObserver(forName: SessionService.LoginSuccess, object: self, queue: OperationQueue.main) { (notification) in
            if self.isBeingPresented {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
}

