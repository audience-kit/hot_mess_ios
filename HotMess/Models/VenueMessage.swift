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
    let userId: UUID
    let avatarUrl: URL
    let conversation: VenueConversation
    
    var direction : Direction {
        if userId == UserService.shared.userId! {
            return .outgoing
        }
        
        return .incoming
    }
    
    init(message : String, conversation: VenueConversation) {
        self.message = message
        self.avatarUrl = URL(string: "/users/\(UserService.shared.userId!.uuidString)/picture", relativeTo: RequestService.shared.baseUrl)!
        self.conversation = conversation
        self.userId = UserService.shared.userId!
    }
    
    init(data : [ String : Any ], conversation: VenueConversation) {
        self.message = data["message"] as! String
        self.avatarUrl = URL(string: data["avatar_url"] as! String)!
        self.conversation = conversation
        self.userId = UUID(uuidString: data["user_id"] as! String)!
    }
    
    // Ugly
    func toJson() -> String {
        let dictionary = [ "type" : "outgoing", "message" : self.message, "user_id" : UserService.shared.userId!.uuidString, "avatar_url" : avatarUrl.absoluteString ] as [String : Any]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted)
        
            return String(data: data, encoding: .utf8)!
        }
        catch {
            return ""
        }
    }
}
