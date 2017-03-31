//
//  RSVPTableViewCell.swift
//  HotMess
//
//  Created by Rick Mark on 3/25/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FacebookCore

class RSVPTableViewCell : UITableViewCell {
    @IBOutlet var goingImage: UIButton?
    @IBOutlet var interestedImage: UIButton?
    @IBOutlet var ignoreImage: UIButton?

    var event: Event? {
        didSet {
            highlightButton()
        }
    }
    
    @IBAction func rsvpTouched(_ sender: UIButton) {
        guard event != nil else { return }
        

        switch sender {
        case goingImage!:
            event!.rsvp = "attending"
        case interestedImage!:
            event!.rsvp = "maybe"
        case ignoreImage!:
            event!.rsvp = "decliend"
        default:
            break;
        }
        
        SessionService.ensureHasPublishPermission(SessionService.RSVPEventPermission) {
            SessionService.ensureHasPermission(SessionService.UserEventsPermission) {
                EventsService.shared.rsvp(self.event!)
                
                self.highlightButton()
            }
        }
    }
    
    override func prepareForReuse() {
        self.event = nil
    }
    
    private func highlightButton() {
        self.goingImage?.isSelected = false
        self.interestedImage?.isSelected = false
        self.ignoreImage?.isSelected = false
        
        let state = self.event?.rsvp ?? "unsure"
        
        switch state {
        case "attending":
            self.goingImage?.isSelected = true
        case "maybe":
            self.interestedImage?.isSelected = true
        case "decliend":
            self.ignoreImage?.isSelected = true
        default:
            break;
        }
    }
}
