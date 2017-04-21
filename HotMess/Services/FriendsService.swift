//
//  FriendsService.swift
//  HotMess
//
//  Created by Rick Mark on 2/23/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class FriendsService {
    static var _shared = FriendsService()
    
    static var shared: FriendsService {
        return _shared
    }
    
    func venue(_ venue: Venue, callback: @escaping ([ Friend ]) -> Void) {
        RequestService.shared.request(relativeUrl: "/v1/venues/\(venue.id)/friends") { (result) in
            let friends = result["friends"] as! [ [ String : Any ] ]
            var parsed: [ Friend ] = []
            
            for friend in friends {
                parsed.append(Friend(friend))
            }
            
            callback(parsed)
        }
    }
}
