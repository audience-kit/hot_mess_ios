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
    
    var venue: Venue?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.refreshControl = UIRefreshControl(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        self.refreshControl?.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        
        NotificationCenter.default.addObserver(forName: LocaleService.kHMLocaleUpdated, object: self, queue: OperationQueue.main) { (notification) in
            self.navigationItem.title = LocaleService.closest?.name
            self.tableView.reloadData()
        }
        
        if let locale = LocaleService.closest {
            self.navigationItem.title = locale.name
        }
        
        self.handleRefresh(control: self.tableView.refreshControl!)
    }
    
    func handleRefresh(control: UIRefreshControl) {
        VenuesService.shared.index { (venues) in
            self.venues = venues
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        
        control.endRefreshing()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "venueCell", for: indexPath)
        
        let venue = venues[indexPath.row]
        
        cell.textLabel?.text = venue.name
        
        if let distance = venue.distance {
            cell.detailTextLabel?.text = "\(String(format: "%.1f", distance)) m"
        }
        else {
            cell.detailTextLabel?.text = ""
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.venues.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.venue = self.venues[indexPath.row]
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let venueViewController = segue.destination as? VenueViewController {
            if let senderCell = sender as? UITableViewCell {
                let indexPath = self.tableView.indexPath(for: senderCell)
                
                venueViewController.venue = self.venues[indexPath!.row]
            }
        }
    }
}

