//
//  Friend.swift
//  HotMess
//
//  Created by Rick Mark on 2/22/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation


class Friend {
    var id: UUID
    var name: String
    var facebookId: IntMax
    
    init(_ data: [ String : Any ]) {
        self.id = UUID(uuidString: data["id"] as! String)!
        self.name = data["name"] as! String
        self.facebookId = data["facebook_id"] as! IntMax
    }
}
