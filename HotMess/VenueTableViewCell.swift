//
//  VenueTableViewCell.swift
//  HotMess
//
//  Created by Rick Mark on 2/5/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FBSDKCoreKit
import Kingfisher

class VenueTableViewCell : UITableViewCell {
    @IBOutlet var nameLabel : UILabel?
    @IBOutlet var distanceLabel : UILabel?
    @IBOutlet var addressLabel: UILabel?
    @IBOutlet var profilePictureView: UIImageView?
    
    func setVenue(venue: Venue) {
        nameLabel?.text = venue.name
        
        if venue.subtitle != nil {
            addressLabel?.text = venue.subtitle!
        } else {
            addressLabel?.text = venue.address
        }
        
        profilePictureView?.kf.setImage(with: venue.photoUrl)
        
        if let distance = venue.distance {
            distanceLabel?.text = DistanceFormatter.shared.string(forMeters: distance)
        }
        else {
            distanceLabel?.text = "unknown"
        }
    }
}
