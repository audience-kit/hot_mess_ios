//
//  EventListing.swift
//  HotMess
//
//  Created by Rick Mark on 3/30/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class EventListing {
    let sections : [ EventSection ]
    let events : [ Event ]
    
    init(_ data: [ String : Any ]) {
        var sections = [ EventSection ]()
        var events: [ Event ]?
        
        events = (data["events"] as! [ [ String : Any ] ]).map { item in
            Event(item)
        }
        
        if let sectionData = data["sections"] as? [ String : Any ] {
            for (name, value) in sectionData {
                sections.append(EventSection(name: name, data: value as! [ String : Any ]))
            }
        }
        
        sections.append(EventSection(events: events!))
        
        self.sections = sections
        self.events = events!
    }
}
