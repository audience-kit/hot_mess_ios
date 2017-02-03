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
        EventsService.shared.index { (events) in
            self.events = events
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let event = self.events[indexPath.row]
        
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "eventCell")
        
        cell?.textLabel?.text = event.name
        cell?.detailTextLabel?.text = "\(formatter!.string(from: event.startDate)) at \(event.venue!.name) "
        
        return cell!
    }
}
