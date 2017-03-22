//
//  VenueConversationViewController.swift
//  HotMess
//
//  Created by Rick Mark on 3/21/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import Atlas

class VenueConversationViewController : UIViewController {
    @IBOutlet var messageCollectionView: UICollectionView?
    @IBOutlet var composeView: ATLMessageComposeTextView?
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(VenueConversationViewController.messageReceived:), name: NSNotification.MessageReceived, object: nil)
        
        super.viewDidLoad()
    }
    
    func messageReceived(_ notification: Notification) {
        messageCollectionView?.insertSections(<#T##sections: IndexSet##IndexSet#>)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
