//
//  FriendTableViewCell.swift
//  HotMess
//
//  Created by Rick Mark on 2/23/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FacebookLogin

class FriendTableViewCell : UITableViewCell {
    @IBOutlet var friendImageView: FBProfilePictureView?
    @IBOutlet var friendNameLabel: UILabel?
    
    func setFriend(_ friend: Friend) {
        friendImageView!.profileID = "\(friend.facebookId)"
        friendImageView!.pictureMode = .square
        friendImageView!.setNeedsImageUpdate()
        friendNameLabel!.text = friend.name
        
        let mask = CAShapeLayer()
        
        mask.fillColor = UIColor.black.cgColor
        mask.path = UIBezierPath(ovalIn: CGRect(origin: CGPoint.zero, size: friendImageView!.frame.size)).cgPath
        
        friendImageView!.layer.mask = mask
    }
}
