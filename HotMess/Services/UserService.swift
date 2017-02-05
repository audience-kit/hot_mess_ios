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
    
    static var shared: UserService {
        return _sharedInstance
    }
    
    func me(callback: @escaping (User) -> Void) {
        RequestService.sharedInstance.request(relativeUrl: "/me") { (result: [String : Any]) in
            if result["id"] != nil {
                callback(User(with: result))
            }
        }
    }
    
    func location(_ location: CLLocation) {
        let location = [ "coordinates": [ "latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude] ]
        
        RequestService.shared.request(relativeUrl: "/me/location", with: location) { result in
            
        }
    }
}
