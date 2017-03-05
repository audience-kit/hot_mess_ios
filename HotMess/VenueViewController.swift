//
//  VenueViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/10/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class VenueViewController : UITableViewController {
    @IBOutlet var heroImage: UIImageView?
    
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
            case 2:
                cell?.textLabel?.text = "facebook"
                cell?.detailTextLabel?.text = "View on Facebook"
            default:
                cell?.textLabel?.text = "invalid"
            }
            
            return cell!
        }
        else {
            if events.count != 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "venueEventCell", for: indexPath) as! EventTableViewCell
                let event = events[indexPath.row]
                cell.setEvent(event: event)
        
                return cell
            }
            else {
                let cell = UITableViewCell()
                cell.textLabel?.text = "No Events"
                
                return cell
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 {
            return 86.0
        }
        
        return 44.0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 3
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
        
        DispatchQueue.global().async {
            do {
                if let photoUrl = self.venue!.photoUrl {
                    let data = try Data(contentsOf: photoUrl)
                    let image = UIImage(data: data)
                    DispatchQueue.main.async {
                        self.heroImage?.image = image
                    }
                }
            }
            catch {
                
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                break
            case 1:
                break
            case 2:
                UIApplication.shared.open(venue!.facebookUrl, options: [:], completionHandler: nil)
            default:
                break
            }
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

