//
//  SecondViewController.swift
//  HotMess
//
//  Created by Rick Mark on 1/2/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class VenuesViewController: UITableViewController {
    
    var venues: [ Venue ] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        VenuesService.shared.index { (venues) in
            self.venues = venues
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LabelCell", for: indexPath)
        
        cell.textLabel?.text = venues[indexPath.row].name
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.venues.count
    }
}

