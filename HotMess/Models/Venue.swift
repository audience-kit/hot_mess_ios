//
//  Venue.swift
//  HotMess
//
//  Created by Rick Mark on 1/10/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation
import GeoJSON
import CoreLocation

class Venue : Model {
    let name: String
    let distance: Double?
    let address: String
    let facebookId: String?
    let phone: String?
    let photoUrl: URL?
    let point: GeoJSONPoint?
    let subtitle: String?
    let isLiked: Bool
    
    var pictureUrl: URL {
        return URL(string: "/venues/\(self.id)/picture", relativeTo: RequestService.shared.baseUrl)!
    }
    
    override init(_ data: [ String: Any]) {
        self.name = data["name"] as! String
        self.facebookId = data["facebook_id"] as? String
        self.phone = data["phone"] as? String
        self.distance = data["distance"] as? Double
        
        if let address = data["address"] as? String {
            self.address = address
        }
        else {
            self.address = "unknown"
        }
        
        if let photoUrlString = data["photo_url"] as? String {
            self.photoUrl = URL(string: photoUrlString)
        }
        else {
            self.photoUrl = nil
        }
        
        if let point = data["point"] as? [ String : Any ] {
            self.point = GeoJSONPoint(dictionary: point)
        }
        else {
            self.point = nil
        }
        
        if let descriptionText = data["description"] as? String {
            self.subtitle = descriptionText
        }
        else {
            self.subtitle = nil
        }
        
        if let isLikedData = data["is_liked"] as? Bool {
            self.isLiked = isLikedData
        }
        else {
            self.isLiked = false
        }
        
        super.init(data)
    }
    
    
    var facebookUrl: URL {
        return URL(string: "https://facebook.com/\(self.facebookId!)")!
    }
    
    var coreLocationPoint: CLLocationCoordinate2D? {
        guard self.point != nil else { return nil }
        
        return CLLocationCoordinate2D(latitude: self.point!.coordinate.latitude, longitude: self.point!.coordinate.longitude)
    }
    
    static func ==(rhs: Venue, lhs: Venue) -> Bool {
        return rhs.id == lhs.id
    }
}
