//
//  FirstViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/2/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class FirstViewController: UIViewController {
    @IBOutlet var label: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        UserService.shared.me { (user) in
            DispatchQueue.main.async {
                self.label?.text = user.name
            }
            
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    @IBAction func refreshButtonPressed(_ sender: UIButton) {
        UserService.shared.me { (user) in
            DispatchQueue.main.async {
                self.label?.text = user.name
            }
        }
    }
    
    @IBAction func logOutButtonPressed(_ sender: UIButton) {
        SessionService.logOut()
    }
}

