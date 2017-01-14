//
//  Event.swift
//  HotMess
//
//  Created by Rick Mark on 1/12/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class Event {
    let id: UUID
    let name: String
    
    init(with: [ String : Any ]) {
        self.id = UUID(uuidString: with["id"] as! String)!
        self.name = with["name"] as! String
    }
}
