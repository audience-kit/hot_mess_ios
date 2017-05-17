//
//  EventSection.swift
//  HotMess
//
//  Created by Rick Mark on 3/30/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class EventSection {
    let title : String
    let name : String
    let items : [ ListingItem ]
    
    init(name: String, data : [ String : Any ]) {
        self.name = name
        
        self.title = data["title"] as! String
        
        self.items = (data["items"] as! [ [ String : Any ] ]).map { item in
            let type = item["type"] as! String
            
            switch type {
            case "link":
                return LinkItem(data)
            default:
                return Event(data)
            }
        }
    }
}
