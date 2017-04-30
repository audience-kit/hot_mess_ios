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
    
    init(_ data: [ String : Any ]) {
        var sections = [ EventSection ]()
        
        if let sectionData = data["sections"] as? [ String : Any ] {
            for (name, value) in sectionData {
                sections.append(EventSection(name: name, data: value as! [ String : Any ]))
            }
        }
        
        self.sections = sections
    }
}
