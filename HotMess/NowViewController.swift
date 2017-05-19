//
//  FirstViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/2/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FacebookCore

class NowViewController: UITableViewController {
    @IBOutlet var heroBanner: UIImageView?
    
    var now : Now?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.heroBanner?.kf.indicatorType = .activity
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(forName: LocationService.LocationChanged, object: nil, queue: OperationQueue.main) { notification in
            self.handleRefresh(control: self.refreshControl!)
        }
    }
    
    @IBAction func handleRefresh(control : UIRefreshControl) {
        DataService.shared.now { (now) in

            if now.imageUrl != nil {
                self.heroBanner?.kf.setImage(with: now.imageUrl!)
            }
            
            DispatchQueue.main.async {
                self.now = now
                self.navigationItem.title = now.title
                self.tableView.reloadData()
                AppEventsLogger.log("show_now", parameters: [ : ], valueToSum: 1, accessToken: AccessToken.current)
            }

        }
        
        control.endRefreshing()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && now?.venues == nil {
            return indexPath.row == 0 ? 120.0 : 60.0
        }
        else if indexPath.section == 0 {
            return 86.0
        }
        
        if indexPath.section == 1 {
            return 86.0
        }
        
        if self.now?.venues == nil {
            return 60.0
        }
        
        return 100.0
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let now = self.now

        if indexPath.section == 0 {
            if now != nil && now!.venues == nil {
                if indexPath.row == 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "nowHereFriendsCell") as! FriendListTableViewCell
                    cell.setFriends(now!.friends)
                    return cell
                }
                
                let cell = tableView.dequeueReusableCell(withIdentifier: "nowFriendInfoCell", for: indexPath)
                cell.textLabel?.text = "Small Talk"
                return cell
            }
            else {
                if now != nil && now!.venues != nil && now!.venues!.venues.count != 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "nowVenueCell") as! VenueTableViewCell
                    
                    let venue = now!.venues!.venues[indexPath.row]
                    cell.setVenue(venue: venue)
                    
                    return cell
                }
                
                let cell = tableView.dequeueReusableCell(withIdentifier: "nowFriendInfoCell")
                
                cell!.textLabel?.text = "You are not near any venues."
                
                return cell!
            }
        }
        
        if now != nil && now!.events.count != 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "nowEventCell") as! EventTableViewCell
            
            let event = self.now!.events[indexPath.row]
            cell.setEvent(event: event)
            
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "nowNoEventsCell")!
        // Prepare for LOC
        cell.textLabel?.text = "There are no upcoming events."
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 && self.now?.venues != nil {
            return min(3, now!.venues!.venues.count)
        }
        else if section == 0 {
            return 1
        }
        
        if now == nil || now?.events.count == 0 {
            return 1
        }
        
        
        return now!.events.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return self.now?.venues == nil ? "People" : "Venues"
        case 1:
            return "Events"
        default:
            return nil
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let path = self.tableView.indexPathForSelectedRow!
        tableView.deselectRow(at: path, animated: true)
        
        switch segue.identifier! {
        case "showEvent":
            let targetViewController = segue.destination as! EventViewController
            let event = self.now!.events[path.row]
            
            targetViewController.event = event
        case "showVenue":
            let targetViewController = segue.destination as! VenueViewController
            let venue = self.now!.venues!.venues[path.row]
            
            targetViewController.venue = venue
            
        case "showVenueChat":
            let targetViewController = segue.destination as! VenueConversationViewController
            targetViewController.conversation = VenueConversation(venue: self.now!.venue!)
        default:
            break;
        }
    }
}

