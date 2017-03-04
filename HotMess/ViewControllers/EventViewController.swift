//
//  EventViewController.swift
//  HotMess
//
//  Created by Rick Mark on 3/1/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class EventViewController : UITableViewController {
    var event: Event? = nil
    
    override func viewWillAppear(_ animated: Bool) {
        guard event != nil else { return }
        
        self.navigationItem.title = event?.name
        
        EventsService.shared.get(event!) { (event) in
            self.event = event
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    
}
