//
//  VenueConversationViewController.swift
//  HotMess
//
//  Created by Rick Mark on 3/21/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class VenueConversationViewController : UIViewController, UICollectionViewDataSource, VenueConversationDelegate {
    internal func messageReceived(message: VenueMessage) {
        messageCollectionView?.insertSections(IndexSet(integer: conversation!.messages.count - 1))
    }

    @IBOutlet var messageCollectionView: UICollectionView?
    @IBOutlet var composeTextView: UITextField?
    
    
    public var conversation : VenueConversation?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //messageCollectionView?.register(ATLIncomingMessageCollectionViewCell.self, forCellWithReuseIdentifier: ATLIncomingMessageCellIdentifier)
        //messageCollectionView?.register(ATLOutgoingMessageCollectionViewCell.self, forCellWithReuseIdentifier: ATLOutgoingMessageCellIdentifier)
        
        //messageCollectionView?.register(ATLConversationCollectionViewMoreMessagesHeader.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: ATLMoreMessagesHeaderIdentifier)
        //messageCollectionView?.register(ATLConversationCollectionViewHeader.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: ATLConversationViewHeaderIdentifier)
        //messageCollectionView?.register(ATLConversationCollectionViewFooter.self, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: ATLConversationViewFooterIdentifier)
        
        let flowLayout = messageCollectionView?.collectionViewLayout as! UICollectionViewFlowLayout
        
        //flowLayout.estimatedItemSize = CGSize(width: view.frame.width, height: ATLMessageBubbleDefaultHeight)
        flowLayout.sectionInset.top = 10
        
        conversation?.delegate = self
        RealtimeService.shared.conversation = self.conversation
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }

    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let currentMessage = conversation!.messages[indexPath.section]
        
        //var reuseIdentifier: String = ATLIncomingMessageCellIdentifier
        
        //if currentMessage.direction == .outgoing {
        //    reuseIdentifier = ATLOutgoingMessageCellIdentifier
        //}
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "", for: indexPath) as! ConversationMessageCell
        
        cell.messageLabel!.text = currentMessage.message
        
        //cell.bubbleView.update(withAttributedText: NSAttributedString(string: currentMessage.message))
        //cell.avatarImageView.kf.setImage(with: currentMessage.avatarUrl)
        
        return cell
    }
    
    @IBAction public func sendMessage(_ sender: UIResponder) {
        let message = VenueMessage(message: self.composeTextView!.text!, conversation: self.conversation!)
        
        self.composeTextView?.text = ""
        
        conversation!.sendMessage(message)
    }
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return conversation!.messages.count
    }
}
