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
    @IBOutlet var pictureView: FBSDKProfilePictureView?
    @IBOutlet var titleLabelView: UILabel?
    
    func setPerson(_ person: Person) {
        self.pictureView?.profileID = "\(person.facebookId)"
        self.pictureView?.setNeedsImageUpdate()
        self.titleLabelView?.text = person.name
    }
}
