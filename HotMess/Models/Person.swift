//
//  Person.swift
//  HotMess
//
//  Created by Rick Mark on 2/12/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class Person : Model {
    let name: String
    let facebookId: IntMax
    let role: String?
    let isLiked: Bool
    
    var pictureUrl: URL {
        return URL(string: "/people/\(self.id)/picture", relativeTo: RequestService.shared.baseUrl)!
    }
    
    var coverUrl: URL {
        return URL(string: "/people/\(self.id)/cover", relativeTo: RequestService.shared.baseUrl)!
    }
    
    override init(_ data: [ String : Any]) {
        self.name = data["name"] as! String
        self.facebookId = data["facebook_id"] as! IntMax
 
        role = data["role"] as? String
        
        if let isLikedData = data["is_liked"] as? Bool {
            self.isLiked = isLikedData
        }
        else {
            self.isLiked = false
        }
        
        
        super.init(data)
    }
    
    var facebookUrl: URL {
        return URL(string: "https://facebook.com/\(self.facebookId)")!
    }
}
