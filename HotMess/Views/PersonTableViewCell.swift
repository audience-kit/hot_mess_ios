//
//  PersonTableViewCell.swift
//  HotMess
//
//  Created by Rick Mark on 2/15/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FBSDKLoginKit

class PersonTableViewCell: UITableViewCell {
    @IBOutlet var pictureView: UIImageView?
    @IBOutlet var titleLabelView: UILabel?
    
    func setPerson(_ person: Person) {
        self.pictureView?.kf.indicatorType = .activity
        self.pictureView?.kf.setImage(with: person.pictureUrl)
        self.titleLabelView?.text = person.name
    }
}
