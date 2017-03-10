//
//  FirstViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/2/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class NowViewController: UITableViewController {
    @IBOutlet var heroBanner: UIImageView?
    
    var now : Now?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.refreshControl = UIRefreshControl(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        
        self.tableView.refreshControl?.addTarget(self, action: #selector(handleRefresh(control:)), for: .valueChanged)
        
        self.handleRefresh(control: self.tableView.refreshControl!)
        
        NotificationCenter.default.addObserver(self, selector: #selector(backgrondRefresh), name: LocaleService.LocationChanged, object: nil)
    }
    
    func backgrondRefresh() -> Void {
        self.handleRefresh(control: self.tableView.refreshControl!)
    }
    
    func handleRefresh(control : UIRefreshControl) {
        NowService.shared.now { (now) in
            if self.now == nil || now != self.now! {
                
                DispatchQueue.global().async {
                    do {
                        if now.imageUrl != nil {
                            let data = try Data(contentsOf: now.imageUrl!)
                            let image = UIImage(data: data)
                            DispatchQueue.main.async {
                                self.heroBanner?.image = image
                            }
                        }
                    }
                    catch {}
                }
                
                DispatchQueue.main.async {
                    self.now = now
                    self.navigationItem.title = now.title
                    self.tableView.reloadData()
                }
            }
        }
        
        control.endRefreshing()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 {
            return 86.0
        }
        
        if self.now?.venue != nil {
            return 60.0
        }
        
        return 100.0
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.section == 0 {
            if now != nil && now!.venue != nil {
                if now == nil || now?.friends.count == 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "nowFriendInfoCell")
                    
                    cell!.textLabel?.text = "You're the first to arrive"
                    
                    return cell!
                }
                else {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "nowFriendCell") as! FriendTableViewCell
                    
                    let friend = self.now!.friends[indexPath.row]
                    cell.setFriend(friend)
                    
                    return cell
                }
            }
            else {
                if now != nil && now!.venues != nil && now!.venues!.venues.count != 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "nowVenueCell") as! VenueTableViewCell
                    
                    let venue = self.now!.venues!.venues[indexPath.row]
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
        if section == 0 {
            if now != nil && now!.venue != nil && now?.friends.count != 0 {
                return now!.friends.count
            }
            else if now != nil && now!.venues != nil && now?.venues?.venues.count != 0 {
                return now!.venues!.venues.count
            }
            
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
            return self.now?.venue != nil ? "Friends Here" : "Venues"
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
        default:
            break;
        }
    }
}

