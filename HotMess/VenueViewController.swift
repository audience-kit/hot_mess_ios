//
//  VenueViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/10/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FBSDKShareKit
import FacebookCore

class VenueViewController : UITableViewController {
    @IBOutlet var heroImage: UIImageView?
    @IBOutlet var likeControl: FBSDKLikeControl?
    
    var venue: Venue?
    var events: [ Event ] = []
    
    override func viewDidLoad() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.action, target: self, action: #selector(EventViewController.actionButton))
        
        self.heroImage?.kf.indicatorType = .activity
        self.likeControl?.objectType = .page
        self.likeControl?.objectID = self.venue!.facebookId
        self.likeControl?.likeControlHorizontalAlignment = .right
    }
    
    func actionButton(_ sender: UIBarButtonItem) {
        let activity = UIActivityViewController(activityItems: [ "https://hotmess.social/venues/\(venue!.id)" ], applicationActivities: nil)
        
        self.present(activity, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "venueDetailCell")
            switch indexPath.row {
            case 0:
                cell?.textLabel?.text = "facebook"
                cell?.detailTextLabel?.text = "View on Facebook"
                cell?.accessoryType = .disclosureIndicator
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
            return 1
        }
        
        return self.events.count == 0 ? 1 : self.events.count
    }
    
    
    override func viewWillAppear(_ animated: Bool) -> Void {
        guard self.venue != nil else { return }
        
        self.navigationItem.title = venue?.name
        
        DataService.shared.events(venue: self.venue!) { (events) in
            self.events = events
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
            
            if let heroUrl = self.venue?.heroUrl {
                self.heroImage?.kf.setImage(with: heroUrl)
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
                UIApplication.shared.open(venue!.facebookUrl, options: [:], completionHandler: nil)
            default:
                break
            }
        }
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let path = self.tableView.indexPathForSelectedRow!
        
        switch segue.identifier! {
        case "showEvent":
            let targetViewController = segue.destination as! EventViewController
            let event = self.events[path.row]
            
            AppEventsLogger.log("show_event", parameters: [ "id" : event.id.uuidString ], valueToSum: 1, accessToken: AccessToken.current)
            
            targetViewController.event = event
        default:
            break;
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

