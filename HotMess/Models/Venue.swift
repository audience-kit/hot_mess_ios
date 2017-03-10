//
//  Venue.swift
//  HotMess
//
//  Created by Rick Mark on 1/10/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation
import GeoJSON

class Venue : Model {
    let id: UUID
    let name: String
    let distance: Double?
    let address: String
    let facebookId: String?
    let phone: String?
    let photoUrl: URL?
    let point: GeoJSONPoint?
    let description: String?
    
    init(with: [ String: Any]) {
        self.id = UUID(uuidString: with["id"] as! String)!
        self.name = with["name"] as! String
        self.facebookId = with["facebook_id"] as? String
        self.phone = with["phone"] as? String
        self.distance = with["distance"] as? Double
        
        if let address = with["address"] as? String {
            self.address = address
        }
        else {
            self.address = "unknown"
        }
        
        if let photoUrlString = with["photo_url"] as? String {
            self.photoUrl = URL(string: photoUrlString)
        }
        else {
            self.photoUrl = nil
        }
        
        if let point = with["point"] as? [ String : Any ] {
            self.point = GeoJSONPoint(dictionary: point)
        }
        else {
            self.point = nil
        }
        
        if let descriptionText = with["description"] as? String {
            self.description = descriptionText
        }
        else {
            self.description = nil
        }
    }
    
    
    var facebookUrl: URL {
        return URL(string: "https://facebook.com/\(self.facebookId!)")!
    }
    
    static func ==(rhs: Venue, lhs: Venue) -> Bool {
        return rhs.id == lhs.id
    }
}
