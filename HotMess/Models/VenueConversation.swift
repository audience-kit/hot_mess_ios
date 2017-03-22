//
//  VenueConversation.swift
//  HotMess
//
//  Created by Rick Mark on 3/19/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation
import Atlas

class VenueConversation : LYRConversation {


    override func send(_ message: LYRMessage) throws {
        NSLog(message.parts.first.debugDescription)
    }
}
