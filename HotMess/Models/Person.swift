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
    
    override init(_ data: [ String : Any]) {
        self.name = data["name"] as! String
        self.facebookId = data["facebook_id"] as! IntMax
 
        super.init(data)
    }
    
    var facebookUrl: URL {
        return URL(string: "https://facebook.com/\(self.facebookId)")!
    }
}
