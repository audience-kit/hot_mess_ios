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
    @IBOutlet var titleLabel: UILabel?
    @IBOutlet var subtitleLabel: UILabel?
    
    var event: Event? = nil
    
    override func viewWillAppear(_ animated: Bool) {
        guard event != nil else { return }
        
        self.navigationItem.title = event?.name
        self.titleLabel?.text = event?.name

        EventsService.shared.get(event!) { (event) in
            self.event = event
        
            DispatchQueue.main.async {
                
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "h:mm"
                
                if event.person != nil {
                    self.facebookProfileImage?.profileID = "\(event.person!.facebookId)"
                    self.facebookProfileImage?.setNeedsImageUpdate()
                    self.subtitleLabel?.text = "\(timeFormatter.string(from: event.startDate)) by \(event.person!.name)"
                }
                else if event.venue != nil {
                    self.facebookProfileImage?.profileID = event.venue!.facebookId
                    self.facebookProfileImage?.setNeedsImageUpdate()
                    self.subtitleLabel?.text = "\(timeFormatter.string(from: event.startDate)) at \(event.venue!.name)"
                }
                
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
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section != 0 {
            return 120.0
        }
        
        return 44.0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard event != nil else { return UITableViewCell() }
        
        if indexPath.section == 0 {
            let infoCell = tableView.dequeueReusableCell(withIdentifier: "eventInfoCell")
            
            infoCell?.detailTextLabel?.text = "Open in Facebook"
            infoCell?.textLabel?.text = "facebook"
            
            return infoCell!
        }
        
        if event?.person != nil && indexPath.section == 1 {
            let hostCell = tableView.dequeueReusableCell(withIdentifier: "eventHostCell") as! PersonTableViewCell
            
            hostCell.setPerson(event!.person!)
            return hostCell
        }
        
        let venueCell = tableView.dequeueReusableCell(withIdentifier: "eventVenueCell") as! VenueTableViewCell
        
        venueCell.setVenue(venue: event!.venue!)
        
        return venueCell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                UIApplication.shared.open(event!.facebookUrl, options: [:], completionHandler: nil)
            default:
                break
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier! {
        case "showPerson":
            let targetViewController = segue.destination as! PersonViewController
            let person = self.event?.person
            
            targetViewController.person = person
        case "showVenue":
            let targetViewController = segue.destination as! VenueViewController
            let venue = self.event?.venue
            
            targetViewController.venue = venue
        default:
            break;
        }
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
