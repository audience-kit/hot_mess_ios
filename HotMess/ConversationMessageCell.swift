//
//  ConversationMessageCell.swift
//  HotMess
//
//  Created by Rick Mark on 3/20/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class ConversationMessageCell : UICollectionViewCell {
    @IBOutlet var messageLabel: UILabel?
    
    func setMessage(_ message: VenueMessage) {
        //messageLabel?.prepareForReuse()
        //messageLabel?.update(withAttributedText: NSAttributedString(string: message.message))
        messageLabel?.text = message.message
    }
}
