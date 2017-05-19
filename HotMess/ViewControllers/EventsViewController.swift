//
//  EventsViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/16/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FacebookCore

class EventsViewController : UITableViewController {
    var listing : EventListing?
    
    var formatter: DateFormatter?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func awakeFromNib() {
        self.formatter = DateFormatter()
        
        self.formatter?.dateFormat = "EEEE MMMM d h:mm"
        
        NotificationCenter.default.addObserver(forName: LocationService.LocaleUpdated, object: self, queue: OperationQueue.main) { (notification) in
            self.handleRefresh(control: self.refreshControl!)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.handleRefresh(control: self.tableView.refreshControl!)
    }
    
    @IBAction func handleRefresh(control: UIRefreshControl) {
        DataService.shared.events { (events) in
            self.listing = events
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        
        control.endRefreshing()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        guard listing != nil else { return 0 }
        
        return listing!.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard listing != nil else { return 0 }
        
        let section = listing?.sections[section]
        
        return section!.items.count == 0 ? 1 : section!.items.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard listing != nil else { return 100 }
        
        if listing!.sections[indexPath.section].items.count == 0 {
            return 100
        }
        
        if listing!.sections[indexPath.section].items[indexPath.row].cellType == "featuredEventCell" {
            return 130
        }
        else {
            return 100
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = listing?.sections[indexPath.section]
        
        if section?.items.count == 0 {
            let noEventsCell = UITableViewCell()
            noEventsCell.textLabel?.text = "No Events"
            return noEventsCell
        }
        
        let item = section?.items[indexPath.row]
        

        let cell = self.tableView.dequeueReusableCell(withIdentifier: item!.cellType)
        
        if let eventCell = cell as? EventTableViewCell {
            eventCell.setEvent(event: item as! Event)
        }
        else if let linkCell = cell as? LinkItemTableViewCell {
            linkCell.setLink(item as! LinkItem)
        }
        
        return cell!
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
            let event = self.listing?.sections[path.section].items[path.row] as! Event
            
            AppEventsLogger.log("show_event", parameters: [ "id" : event.id.uuidString ], valueToSum: 1, accessToken: AccessToken.current)
            
            targetViewController.event = event
        default:
            break;
        }
    }
}
