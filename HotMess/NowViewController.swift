//
//  FirstViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/2/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class NowViewController: UITableViewController {

    @IBOutlet var titleLabel: UILabel?
    
    var venue: Venue?
    var events = [ Event ]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        VenuesService.shared.closest { (venue) in
            self.venue = venue
            
            DispatchQueue.main.async {
                self.titleLabel?.text = venue.name
            }
            
            EventsService.shared.index(venue: venue, callback: { (events) in
                self.events = events
            
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            })
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "nowHeroCell")
            
            return cell!
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "nowEventCell")!
        
        if events.count == 0 {
            cell.textLabel?.text = "No Events"
            cell.accessoryType = .none
        }
        else {
            let event = self.events[indexPath.row]
            cell.textLabel?.text = event.name
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        
        if events.count == 0 {
            return 1
        }
        
        
        return events.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1:
            return "Events"
        default:
            return nil
        }
    }
}

