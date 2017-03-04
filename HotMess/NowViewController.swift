//
//  FirstViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/2/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class NowViewController: UITableViewController {
    var imageViewCell: HeroTableViewCell?
    
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
            
                self.now = now
                
                do {
                    let data = try Data(contentsOf: now.venue.photoUrl!)
                    let image = UIImage(data: data)
                    DispatchQueue.main.async {
                        self.imageViewCell?.imageViewCustom?.image = image
                    }
                }
                catch {}
                
                DispatchQueue.main.async {
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
        if indexPath.section == 0 {
            return 200.0
        }
        
        if indexPath.section == 1 {
            return 60.0
        }
        
        return 44.0
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "nowHeroCell")
            
            self.imageViewCell = cell as? HeroTableViewCell
            
            return cell!
        }
        
        if indexPath.section == 1 {
            
            
            if now == nil || now?.friends.count == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "nowFriendInfoCell")
                
                cell!.textLabel?.text = "You're the first to arrive"
                
                return cell!
            }
            else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "nowFriendCell") as! FriendTableViewCell
                
                cell.textLabel?.text = nil
                let friend = self.now!.friends[indexPath.row]
                
                cell.setFriend(friend)
                
                return cell
            }
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "nowEventCell")!
        
        if now == nil || now?.events.count == 0 {
            cell.textLabel?.text = "No Events"
            cell.accessoryType = .none
        }
        else {
            let event = self.now!.events[indexPath.row]
            cell.textLabel?.text = event.name
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        
        if section == 1 {
            if now == nil || now?.friends.count == 0 {
                return 1
            }
            
            return now!.friends.count
        }
        
        if now == nil || now?.events.count == 0 {
            return 1
        }
        
        
        return now!.events.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1:
            return "Friends Here"
        case 2:
            return "Events"
        default:
            return nil
        }
    }
    
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let path = self.tableView.indexPathForSelectedRow!
        
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

