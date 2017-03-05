//
//  File.swift
//  HotMess
//
//  Created by Rick Mark on 3/1/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FBSDKCoreKit
import FBSDKShareKit

class PersonViewController : UITableViewController {
    @IBOutlet var personProfileImage: FBSDKProfilePictureView?
    @IBOutlet var personTitleLabel: UILabel?
    @IBOutlet var personLikeButton: FBSDKLikeControl?
    
    var person: Person? = nil
    
    
    override func viewWillAppear(_ animated: Bool) {
        guard person != nil else { return }
        
        self.navigationItem.title = person?.name
        
        self.personLikeButton?.objectType = FBSDKLikeObjectType.page
        self.personLikeButton?.likeControlStyle = .boxCount
        
        PeopleService.shared.get(person!) { (person) in
            DispatchQueue.main.async {
                self.person = person
                self.personProfileImage?.profileID = "\(person.facebookId)"
                self.personProfileImage?.setNeedsImageUpdate()
                self.personTitleLabel?.text = person.name
                self.personLikeButton?.objectID = "\(person.facebookId)"

                
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
            return 1
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
                infoCell?.detailTextLabel?.text = "View on Facebook"
                infoCell?.textLabel?.text = "facebook"
            default:
                break
            }
            
            return infoCell!
        case 1:
            let eventCell = tableView.dequeueReusableCell(withIdentifier: "personEventCell") as! EventTableViewCell
            
            let event = person?.events[indexPath.row]
            eventCell.setEvent(event: event!)
            
            return eventCell
        default:
            break
        }
        
        return UITableViewCell()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            UIApplication.shared.open(person!.facebookUrl, options: [:], completionHandler: nil)
        }

        self.tableView.deselectRow(at: indexPath, animated: true)
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
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return "Events"
        }
        
        return nil
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 {
            return 86.0
        }
        
        return 44.0
    }
}
