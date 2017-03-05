//
//  EventViewController.swift
//  HotMess
//
//  Created by Rick Mark on 3/1/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FBSDKCoreKit
import FBSDKShareKit

class EventViewController : UITableViewController {
    @IBOutlet var facebookProfileImage: FBSDKProfilePictureView?
    
    var event: Event? = nil
    
    override func viewWillAppear(_ animated: Bool) {
        guard event != nil else { return }
        
        self.navigationItem.title = event?.name
        
        EventsService.shared.get(event!) { (event) in
            self.event = event
            
            if event.person != nil {
                self.facebookProfileImage?.profileID = "\(event.person!.facebookId)"
                self.facebookProfileImage?.setNeedsImageUpdate()
            }
            else if event.venue != nil {
                self.facebookProfileImage?.profileID = "\(event.venue!.facebookId)"
                self.facebookProfileImage?.setNeedsImageUpdate()
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return nil
        }
        
        if event?.person != nil && section == 1 {
            return "Host"
        }
        
        return "Venue"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        var count: Int = 1
        
        if event?.person != nil {
            count += 1
        }
        
        if event?.venue != nil {
            count += 1
        }
        
        return count
    }
}
