//
//  HeroViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/3/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FBSDKLoginKit

class HeroViewController : UIViewController {
    @IBOutlet var loginButton: FBSDKLoginButton?
    
    override func viewDidLoad() {
        if ((FBSDKAccessToken.current()) != nil)
        {
            self.performSegue(withIdentifier: "loginSuccess", sender: self)
        }
    }
}

