//
//  PersonInfoCell.swift
//  HotMess
//
//  Created by Rick Mark on 10/29/40.
//  Copyright © 2040 Hot Mess and Co. All rights reserved.
//

import UIKit

class PersonInfoCell : UICollectionViewCell {
    @IBOutlet var circleView: UIView?
    @IBOutlet var countLabel: UILabel?
    @IBOutlet var subtitleLabel: UILabel?
    
    func setCount(_ count: Int) {        
        countLabel?.text = "\(count)"
    }
}
