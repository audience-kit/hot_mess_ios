//
//  EventsViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/16/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class EventsViewController : UITableViewController {
    var listing : EventListing?
    
    var formatter: DateFormatter?
    
    override func awakeFromNib() {
        self.formatter = DateFormatter()
        
        self.formatter?.dateFormat = "EEEE MMMM d h:mm"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.refreshControl = UIRefreshControl(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        
        self.tableView.refreshControl?.addTarget(self, action: #selector(handleRefresh(control:)), for: .valueChanged)
        
        self.handleRefresh(control: self.tableView.refreshControl!)
    }
    
    func handleRefresh(control: UIRefreshControl) {
        EventsService.shared.index { (events) in
            self.listing = events
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        
        control.endRefreshing()
    }
    
    var isAuthorized : Bool {
        return false
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        guard listing != nil else { return 0 }
        
        return listing!.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard listing != nil else { return 0 }
        
        let section = listing?.sections[section]
        
        return section!.events.count == 0 ? 1 : section!.events.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = listing?.sections[indexPath.section]
        
        if section?.events.count == 0 {
            let noEventsCell = UITableViewCell()
            noEventsCell.textLabel?.text = "No Events"
            return noEventsCell
        }
        
        let event = section?.events[indexPath.row]
        
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "eventCell") as! EventTableViewCell
        cell.setEvent(event: event!)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard listing != nil else { return nil }
        
        let section = listing?.sections[section]
        
        return section!.title
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let path = self.tableView.indexPathForSelectedRow!
        
        switch segue.identifier! {
        case "showEvent":
            let targetViewController = segue.destination as! EventViewController
            let event = self.listing?.events[path.row]
            
            targetViewController.event = event
        default:
            break;
        }
    }
}
