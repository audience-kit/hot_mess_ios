//
//  Locale.swift
//  HotMess
//
//  Created by Rick Mark on 2/2/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class Locale : Model {
    let id: UUID
    let name: String
    
    init(_ data: [ String : Any ]) {
        self.id = UUID(uuidString: data["id"] as! String)!
        self.name = data["name"] as! String
    }
    
    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}
