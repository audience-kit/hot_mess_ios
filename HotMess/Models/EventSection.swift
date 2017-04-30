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
    let events : [ Event ]
    
    init(name: String, data : [ String : Any ]) {
        self.name = name
        
        self.title = data["title"] as! String
        
        self.events = (data["events"] as! [ [ String : Any ] ]).map { (event) in
            Event(event)
        }
    }
}
