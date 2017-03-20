//
//  PersonCell.swift
//  HotMess
//
//  Created by Rick Mark on 3/20/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class PersonCell : UICollectionViewCell {
    @IBOutlet var imageView: UIImageView?
    @IBOutlet var nameLabel: UILabel?
    
    func setPerson(_ friend: Friend) {
        let mask = CAShapeLayer()
        
        mask.fillColor = UIColor.black.cgColor
        mask.path = UIBezierPath(ovalIn: CGRect(origin: CGPoint.zero, size: imageView!.frame.size)).cgPath
        
        imageView?.layer.mask = mask
        
        imageView?.kf.setImage(with: friend.profileImageUrl)
        nameLabel?.text = friend.firstName
    }
}
