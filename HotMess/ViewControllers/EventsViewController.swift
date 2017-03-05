//
//  EventsViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/16/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class EventsViewController : UITableViewController {
    var events : [ Event ] = []
    
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
            self.events = events
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        
        control.endRefreshing()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if events.count == 0 {
            return 1
        }
        
        return events.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if events.count == 0 {
            let noEventsCell = UITableViewCell()
            noEventsCell.textLabel?.text = "No Events"
            return noEventsCell
        }
        
        let event = self.events[indexPath.row]
        
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "eventCell") as! EventTableViewCell
        cell.setEvent(event: event)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Upcoming..."
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let path = self.tableView.indexPathForSelectedRow!
        
        switch segue.identifier! {
        case "showEvent":
            let targetViewController = segue.destination as! EventViewController
            let event = self.events[path.row]
            
            targetViewController.event = event
        default:
            break;
        }
    }
}
