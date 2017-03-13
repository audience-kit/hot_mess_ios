//
//  Friend.swift
//  HotMess
//
//  Created by Rick Mark on 2/22/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation


class Friend : Model {
    var name: String
    var facebookId: IntMax
    
    override init(_ data: [ String : Any ]) {
        self.name = data["name"] as! String
        self.facebookId = data["facebook_id"] as! IntMax
        
        super.init(data)
    }
    
    static func ==(rhs: Friend, lhs: Friend) -> Bool {
        return rhs.id == lhs.id
    }
}
