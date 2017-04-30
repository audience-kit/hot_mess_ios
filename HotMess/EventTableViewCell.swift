//
//  EventTableViewCell.swift
//  HotMess
//
//  Created by Rick Mark on 2/5/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class EventTableViewCell : UITableViewCell {
    
    @IBOutlet var titleLabel: UILabel?
    @IBOutlet var subtitleLabel: UILabel?
    @IBOutlet var monthLabel: UILabel?
    @IBOutlet var dayLabel: UILabel?
    @IBOutlet var coverPhotoImage: UIImageView?
    
    func setEvent(event: Event) {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm"
        
        titleLabel?.text = event.name
        subtitleLabel?.text = "\(timeFormatter.string(for: event.startDate)!) at \(event.venue!.name)"
        monthLabel?.text = monthFormatter.string(from: event.startDate).uppercased()
        dayLabel?.text = dayFormatter.string(for: event.startDate)
        
        if coverPhotoImage != nil {
            coverPhotoImage!.kf.setImage(with: event.coverUrl!)
        }
    }
}
