//
//  Now.swift
//  HotMess
//
//  Created by Rick Mark on 2/23/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class Now {
    var title: String
    
    var events : [ Event ]
    var venue : Venue? 
    var friends : [ Friend ]
    var venues : Venues?
    var imageUrl : URL?
    
    init(_ data : [ String : Any ]) {
        self.title = data["title"] as! String
        
        if let venueData = data["venue"] as? [ String : Any ] {
            self.venue = Venue(with: venueData)
        }
        
        if data["venues"] != nil {
            self.venues = Venues(data)
        }
        
        var friends = [ Friend ]()
        var events = [ Event ]()
        
        if let friendData = data["friends"] as? [ [ String : Any ] ] {
            for friend in friendData {
                let friend = Friend(friend)
                
                friends.append(friend)
            }
        }
        self.friends = friends
        
        for event in data["events"] as! [ [ String : Any ] ] {
            let event = Event(with: event)
            
            events.append(event)
        }
        
        self.events = events
        
        if let imageUrl = data["image_url"] as? String {
            self.imageUrl = URL(string: imageUrl)!
        }
    }
    
    static func ==(lhs: Now, rhs: Now) -> Bool {
        return rhs.title == lhs.title &&
               rhs.friends.elementsEqual(lhs.friends, by: { (flhs, frhs) -> Bool in flhs == frhs }) &&
               rhs.events.elementsEqual(lhs.events, by: { (elhs, erhs) -> Bool in elhs == erhs })
    }
    
    static func !=(lhs: Now, rhs: Now) -> Bool {
        return !(lhs == rhs)
    }
}
