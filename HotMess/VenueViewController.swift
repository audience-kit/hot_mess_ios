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
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "venueDetailCell")
            switch indexPath.row {
            case 0:
                cell?.textLabel?.text = "address"
                cell?.detailTextLabel?.text = venue!.address
            case 1:
                cell?.textLabel?.text = "phone"
                cell?.detailTextLabel?.text = venue!.phone
            default:
                cell?.textLabel?.text = "invalid"
            }
            
            return cell!
        }
        else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "venueEventCell", for: indexPath)
        
            if events.count == 0 {
                
                cell.textLabel?.text = "No Events"
                cell.accessoryType = .none
            }
            else {
                cell.textLabel?.text = events[indexPath.row].name
                cell.accessoryType = .disclosureIndicator
            }
        
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 2
        }
        
        if self.events.count == 0 {
            return 1
        }
        
        return self.events.count
    }
    
    
    override func viewWillAppear(_ animated: Bool) -> Void {
        guard self.venue != nil else { return }
        
        self.navigationItem.title = venue?.name
        
        EventsService.shared.index(venue: self.venue!) { (events) in
            self.events = events
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        
        if indexPath.section == 1 && events.count != 0 {
            let event = events[indexPath.row]
            
            UIApplication.shared.open(event.facebookUrl, options: [:], completionHandler: nil)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "about"
        case 1:
            return "events"
        default:
            return "invalid"
        }
    }
}

