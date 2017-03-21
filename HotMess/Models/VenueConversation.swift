//
//  VenueConversation.swift
//  HotMess
//
//  Created by Rick Mark on 3/19/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class VenueConversation {
    
    var messages = [ VenueMessage ]()
    
    init() {
        messages.append(VenueMessage("One"))
        messages.append(VenueMessage("Two"))
        messages.append(VenueMessage("Three"))
    }
}
