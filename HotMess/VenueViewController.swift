//
//  VenueViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/10/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class VenueViewController : UITableViewController {
    var venue: Venue?
    var events: [ Event ] = []
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LabelCell", for: indexPath)
        
        cell.textLabel?.text = events[indexPath.row].name
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.events.count
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        guard self.venue != nil else { return }
        
        EventsService.shared.index(venue: self.venue!) { (events) in
            self.events = events
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
}

