//
//  Person.swift
//  HotMess
//
//  Created by Rick Mark on 2/12/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class Person : Model {
    let id: UUID
    let name: String
    let facebookId: IntMax
    let soundCloudId: String?
    let instagramId: String?
    let twitterId: String?
    
    let events: [ Event ]
    
    init(_ data: [ String : Any]) {
        self.id = UUID(uuidString: data["id"] as! String)!
        self.name = data["name"] as! String
        self.facebookId = data["facebook_id"] as! IntMax
        
        self.soundCloudId = nil
        self.instagramId = nil
        self.twitterId = nil
        
        if let eventsData = data["events"] as? [ [ String : Any ] ] {
            var events = [ Event ]()
            
            for eventData in eventsData {
                events.append(Event(with: eventData))
            }
            
            self.events = events
        }
        else {
            self.events = [ Event ]()
        }
    }
    
    var facebookUrl: URL {
        return URL(string: "https://facebook.com/\(self.facebookId)")!
    }
}
