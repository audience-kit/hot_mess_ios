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
    let startDate: Date
    let facebookId: IntMax
    let venue: Venue?
    
    init(with: [ String : Any ]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        self.id = UUID(uuidString: with["id"] as! String)!
        self.name = with["name"] as! String
        let startAt = with["start_at"] as! String
        self.startDate = formatter.date(from: startAt)!
        self.facebookId = with["facebook_id"] as! IntMax
        
        if let venue_data = with["venue"] as? [ String : Any ] {
            self.venue = Venue(with: venue_data)
        }
        else {
            venue = nil
        }
    }
    
    var facebookUrl : URL {
        return URL(string: "https://facebook.com/events/\(self.facebookId)")!
    }
    
    static func ==(rhs: Event, lhs: Event) -> Bool {
        return rhs.id == lhs.id
    }
}
