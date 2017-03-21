//
//  VenueMessagesController.swift
//  HotMess
//
//  Created by Rick Mark on 3/20/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import Atlas
import Kingfisher

class VenueMessagesController : NSObject, UICollectionViewDataSource {
    let conversation: VenueConversation
    
    init(_ conversation: VenueConversation) {
        self.conversation = conversation
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return conversation.messages.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ATLOutgoingMessageCellIdentifier, for: indexPath) as! ATLMessageCollectionViewCell
        
        let message = self.conversation.messages[indexPath.row]
        
        cell.bubbleView.update(withAttributedText: NSAttributedString(string: message.message))
        
        var options: KingfisherOptionsInfo = [.transition(.fade(0.3)), .backgroundDecode]
        let processor = ResizingImageProcessor(targetSize: CGSize(width: 30, height: 30))
        options.append(.processor(processor))
        
        //cell.avatarImageView.kf.setImage(with: URL(string: "/venues/f38046f1-2d6b-4881-9864-8cd182585710/picture", relativeTo: RequestService.shared.baseUrl)!, options: options)
        
        
        
        return cell
    }
    
    
    

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
}
