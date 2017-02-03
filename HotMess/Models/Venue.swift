//
//  Venue.swift
//  HotMess
//
//  Created by Rick Mark on 1/10/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class Venue {
    let id: UUID
    let name: String
    let distance: Double?
    
    init(with: [ String: Any]) {
        self.id = UUID(uuidString: with["id"] as! String)!
        
        self.name = with["name"] as! String
        
        self.distance = with["distance"] as? Double
    }
}
