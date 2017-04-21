//
//  NowService.swift
//  HotMess
//
//  Created by Rick Mark on 2/23/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation


class NowService {
    
    static var _shared = NowService()
    
    
    static var shared : NowService {
        return _shared
    }
    
    func now(callback: @escaping (Now) -> Void) -> Void {
        RequestService.shared.request(relativeUrl: "/v1/now?\(LocaleService.shared.coordinates.queryParameters)") { (data) in
            callback(Now(data))
        }
    }
}
