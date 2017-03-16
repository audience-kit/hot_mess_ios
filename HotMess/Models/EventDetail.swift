//
//  EventDetail.swift
//  HotMess
//
//  Created by Rick Mark on 3/14/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class EventDetail : Event {
    let people: [ Person ]
    
    override init(_ data: [ String : Any ]) {
        var people = [ Person ]()
        if let peopleData = data["people"] as? [ [ String : Any ] ] {
            for personData in peopleData {
                people.append(Person(personData))
            }
        }
        
        self.people = people
        super.init(data)
    }
    
    
}
