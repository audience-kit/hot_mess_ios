//
//  PeopleViewController.swift
//  HotMess
//
//  Created by Rick Mark on 2/12/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit


class PeopleViewController : UITableViewController {
    var people = [ Person ]()
    
    override func viewDidLoad() {
        self.tableView.refreshControl = UIRefreshControl(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        
        self.tableView.refreshControl?.addTarget(self, action: #selector(handleRefresh(control:)), for: .valueChanged)
        
        self.handleRefresh(control: self.tableView.refreshControl!)
    }
    
    func handleRefresh(control: UIRefreshControl) {
        PeopleService.shared.index { (people) in
            self.people = people
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
            
            control.endRefreshing()
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return people.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "personCell") as! PersonTableViewCell
        let person = people[indexPath.row]
        
        cell.setPerson(person)
        
        return cell
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let path = self.tableView.indexPathForSelectedRow!
        
        switch segue.identifier! {
        case "showPerson":
            let targetViewController = segue.destination as! PersonViewController
            let person = self.people[path.row]
            
            targetViewController.person = person
        default:
            break;
        }
    }
}
