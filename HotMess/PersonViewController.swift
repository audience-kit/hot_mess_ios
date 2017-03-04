//
//  File.swift
//  HotMess
//
//  Created by Rick Mark on 3/1/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class PersonViewController : UITableViewController {
    
    var person: Person? = nil
    
    override func viewWillAppear(_ animated: Bool) {
        guard person != nil else { return }
        
        self.navigationItem.title = person?.name
        
        PeopleService.shared.get(person!) { (person) in
            DispatchQueue.main.async {
                self.person = person
                self.tableView.reloadData()
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2
        case 1:
            return person != nil ? person!.events.count : 0
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let infoCell = tableView.dequeueReusableCell(withIdentifier: "personInfoCell")
            
            switch indexPath.row {
            case 0:
                infoCell?.textLabel?.text = person?.name
            case 1:
                infoCell?.textLabel?.text = "\(person?.facebookId)"
            default:
                break
            }
            
            return infoCell!
        case 1:
            let eventCell = tableView.dequeueReusableCell(withIdentifier: "personEventCell")
            
            eventCell?.textLabel?.text = person?.events[indexPath.row].name
            
            return eventCell!
        default:
            break
        }
        
        return UITableViewCell()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let path = self.tableView.indexPathForSelectedRow!
        
        switch segue.identifier! {
        case "showEvent":
            let targetViewController = segue.destination as! EventViewController
            let event = self.person?.events[path.row]
            
            targetViewController.event = event
        default:
            break;
        }
    }
}
