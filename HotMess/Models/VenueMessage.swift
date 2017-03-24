//
//  VenueMessage.swift
//  HotMess
//
//  Created by Rick Mark on 3/20/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class VenueMessage {
    enum Direction {
        case incoming
        case outgoing
    }
    
    let message: String
    let direction: Direction
    let userId: UUID
    
    init(message : String) {
        self.message = message
        self.direction = .outgoing
        self.userId = UserService.shared.userId!
    }
    
    init(data : [ String : Any ]) {
        self.message = "\(data["message"])"
        self.direction = .incoming
        self.userId = UUID(uuidString: data["user_id"] as! String)!
    }
    
    // Ugly
    func toJson() -> String {
        let dictionary = [ "type" : "outgoing", "message" : self.message, "user_id" : self.userId.uuidString ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted)
        
            return String(data: data, encoding: .utf8)!
        }
        catch {
            return ""
        }
    }
}
