//
//  VenueTableViewCell.swift
//  HotMess
//
//  Created by Rick Mark on 2/5/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class VenueTableViewCell : UITableViewCell {
    @IBOutlet var nameLabel : UILabel?
    @IBOutlet var distanceLabel : UILabel?
    @IBOutlet var addressLabel: UILabel?
    
    func setVenue(venue: Venue) {
        nameLabel?.text = venue.name
        addressLabel?.text = venue.address
        
        if let distance = venue.distance {
            distanceLabel?.text = "\(distance)"
        }
        else {
            distanceLabel?.text = "unknown"
        }
    }
}
