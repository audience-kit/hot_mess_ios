//
//  User.swift
//  HotMess
//
//  Created by Rick Mark on 1/6/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class User {
    let id: UUID
    
    init(with: [ String : Any ]) {
        // TODO: HORIBLE series of assertions
        id = UUID(uuidString: with["id"] as! String)!
    }
}
