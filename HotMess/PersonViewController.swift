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
import FacebookCore

class PersonViewController : UITableViewController {
    @IBOutlet var personProfileImage: UIImageView?
    @IBOutlet var personCoverImage: UIImageView?
    @IBOutlet var personTitleLabel: UILabel?
    
    var person: Person? = nil
    
    var personDetail: PersonDetail? {
        return person as? PersonDetail
    }
    
    override func viewWillAppear(_ animated: Bool) {
        guard person != nil else { return }
        
        self.navigationItem.title = person?.name
        
        self.personProfileImage?.kf.indicatorType = .activity
        
        self.personProfileImage?.layer.borderColor = UIColor.white.cgColor
        self.personProfileImage?.layer.borderWidth = 5.0
        self.personProfileImage?.kf.setImage(with: person?.pictureUrl)

        
        DataService.shared.person(person!.id) { (person) in
            DispatchQueue.main.async {
                self.person = person
                self.personTitleLabel?.text = person.name
                self.personCoverImage?.kf.setImage(with: person.coverUrl)

                self.tableView.reloadData()
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return personDetail != nil && personDetail!.tracks.count != 0 ? 3 : 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return personDetail == nil ? 0 :  personDetail!.socialLinks.count
        case 1:
            return personDetail != nil && personDetail!.events.count != 0 ? personDetail!.events.count : 1
        case 2:
            return personDetail!.tracks.count
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let infoCell = tableView.dequeueReusableCell(withIdentifier: "personInfoCell")!
            
            let link = personDetail!.socialLinks[indexPath.row]
            infoCell.textLabel?.text = "/\(link.handle)"
            switch link.provider {
            case "facebook":
                infoCell.imageView?.image = #imageLiteral(resourceName: "Facebook")
            case "soundcloud":
                infoCell.imageView?.image = #imageLiteral(resourceName: "SoundCloud")
            case "instagram":
                infoCell.imageView?.image = #imageLiteral(resourceName: "Instagram")
            case "twitter":
                infoCell.imageView?.image = #imageLiteral(resourceName: "Twitter")
            default:
                break
            }

            return infoCell
        case 1:

            if personDetail != nil && personDetail!.events.count != 0 {
                let eventCell = tableView.dequeueReusableCell(withIdentifier: "personEventCell") as! EventTableViewCell
                
                let event = personDetail?.events[indexPath.row]
                eventCell.setEvent(event: event!)
                return eventCell
            }
            
            let cell = UITableViewCell()
            cell.textLabel?.text = "No upcoming events"
            return cell
        case 2:
            let trackCell = tableView.dequeueReusableCell(withIdentifier: "personTrackCell") as! TrackTableViewCell
            let track = personDetail!.tracks[indexPath.row]
            
            trackCell.setTrack(track)
            
            return trackCell
        default:
            break
        }
        
        return UITableViewCell()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let link = personDetail!.socialLinks[indexPath.row]
            UIApplication.shared.open(link.url, options: [:], completionHandler: nil)
        }
        if indexPath.section == 2 {
            let track = personDetail!.tracks[indexPath.row]
            UIApplication.shared.open(track.providerUrl, options: [:], completionHandler: nil)
        }

        self.tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let path = self.tableView.indexPathForSelectedRow!
        
        switch segue.identifier! {
        case "showEvent":
            let targetViewController = segue.destination as! EventViewController
            let event = self.personDetail!.events[path.row]
            
            AppEventsLogger.log("show_event_from_person", parameters: [ "id" : person!.id.uuidString, "event_id" : event.id.uuidString ], valueToSum: 1, accessToken: AccessToken.current)
            
            targetViewController.event = event
        default:
            break;
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1:
            return "Events"
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 2 {
            let imageView = UIImageView(image: #imageLiteral(resourceName: "PoweredBySoundCloud"))
            
            imageView.contentMode = .left
            
            return imageView
        }
        
        return super.tableView(tableView, viewForHeaderInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return 58.0
        case 1:
            return 86.0
        case 2:
            return 120.0
        default:
            return 44.0
        }
    }
}
