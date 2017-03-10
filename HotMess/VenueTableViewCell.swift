//
//  VenueTableViewCell.swift
//  HotMess
//
//  Created by Rick Mark on 2/5/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FBSDKCoreKit

class VenueTableViewCell : UITableViewCell {
    @IBOutlet var nameLabel : UILabel?
    @IBOutlet var distanceLabel : UILabel?
    @IBOutlet var addressLabel: UILabel?
    @IBOutlet var profilePictureView: FBSDKProfilePictureView?
    
    func setVenue(venue: Venue) {
        nameLabel?.text = venue.name
        
        if venue.description != nil {
            addressLabel?.text = venue.description!
        } else {
            addressLabel?.text = venue.address
        }
        
        profilePictureView?.profileID = venue.facebookId
        profilePictureView?.setNeedsImageUpdate()
        
        if let distance = venue.distance {
            distanceLabel?.text = DistanceFormatter.shared.string(forMeters: distance)
        }
        else {
            distanceLabel?.text = "unknown"
        }
    }
}
