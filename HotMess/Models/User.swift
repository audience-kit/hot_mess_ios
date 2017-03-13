    //
//  User.swift
//  HotMess
//
//  Created by Rick Mark on 1/6/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class User : Model {
    let name: String
    
    override init(_ data: [ String : Any ]) {
        // TODO: HORIBLE series of assertions
        name = data["name"] as! String
        
        super.init(data)
    }
}
