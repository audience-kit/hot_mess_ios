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
    
    func me(callback: (User) -> Void) {
        RequestService.sharedInstance.request(relativeUrl: "/me", with: [:]) { (result: [String : Any]) in
            callback(User(with: result))
        }
    }
}
