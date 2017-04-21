//
//  VenueConversation.swift
//  HotMess
//
//  Created by Rick Mark on 3/19/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

protocol VenueConversationDelegate {
    func messageReceived(message: VenueMessage)
}

class VenueConversation {
    var messages : [ VenueMessage ]
    
    var venue: Venue
    
    var delegate: VenueConversationDelegate?
    
    init(venue: Venue) {
        self.venue = venue
        messages = [ VenueMessage ]()
        
        RealtimeService.shared.subscribe("RealtimeChannel", other: [ "venue_id": "chat_\(venue.id.uuidString)"])
    }
    
    func messageReceived(message: VenueMessage) {
        // Not thread safe, need to put into local variable (Atomic)
        guard delegate != nil else { return }
        
        messages.append(message)
        delegate!.messageReceived(message: message)
    }
    
    func sendMessage(_ message: VenueMessage) {
        RealtimeService.shared.sendMessage(message)
    }
}
