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
        self.navigationItem.title = person?.name
        
        PeopleService.shared.get(person!) { (person) in
            DispatchQueue.main.async {
                self.person = person
                self.tableView.reloadData()
            }
        }
    }
}
