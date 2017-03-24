//
//  UserService.swift
//  HotMess
//
//  Created by Rick Mark on 1/6/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class UserService {
    private static let _sharedInstance = UserService()
    private var lastUpdate = Date.distantPast
    private let updateInterval = TimeInterval(exactly: 30.0)!
    
    var userId: UUID?
    
    static var shared: UserService {
        return _sharedInstance
    }
    
    func me(callback: @escaping (User) -> Void) {
        RequestService.shared.request(relativeUrl: "/me") { (result: [String : Any]) in
            if result["id"] != nil {
                let user = User(result)
                self.userId = user.id
                callback(user)
            }
        }
    }
    
    func location(_ location: CLLocation, beaconMajor: Int = 0, beaconMinor: Int = 0) {
        let location = [ "coordinates": [ "latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude], "beacon": [ "major": beaconMajor, "minor": beaconMinor] ] as [String : Any]
        
        RequestService.shared.request(relativeUrl: "/me/location", with: location) { result in
            
        }
    }
}
