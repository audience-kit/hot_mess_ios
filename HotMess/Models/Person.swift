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
    let pictureUrl: URL
    let coverUrl: URL?
    
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
        
        self.pictureUrl = URL(string: data["photo_url"] as! String)!
        
        if let coverUrl = data["cover_url"] as? String {
            self.coverUrl = URL(string: coverUrl)!
        }
        else {
            self.coverUrl = nil
        }
        
        super.init(data)
    }
    
    var facebookUrl: URL {
        return URL(string: "https://facebook.com/\(self.facebookId)")!
    }
}
