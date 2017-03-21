//
//  ConversationCell.swift
//  HotMess
//
//  Created by Rick Mark on 3/19/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import Atlas

class ConversationTableViewCell : UITableViewCell {
    @IBOutlet var conversationView: ATLConversationView?
    
    var venueConversation : VenueConversation?
    var dataSource: UICollectionViewDataSource?
    
    var conversationMessageView: ATLConversationCollectionView?

    func setConversation(_ conversation: VenueConversation) {
        let layout = UICollectionViewFlowLayout()
        self.conversationMessageView = ATLConversationCollectionView(frame: conversationView!.frame, collectionViewLayout: layout)
        
        self.venueConversation = conversation
        self.dataSource = VenueMessagesController(conversation)
        self.conversationMessageView!.dataSource = self.dataSource
        
        conversationView?.addSubview(self.conversationMessageView!)
        DispatchQueue.main.async {
            self.conversationMessageView?.reloadData()
        }
        
    }

}
