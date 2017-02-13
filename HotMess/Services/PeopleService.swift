//
//  PeopleService.swift
//  HotMess
//
//  Created by Rick Mark on 2/12/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class PeopleService {
    private static let _sharedInstance = PeopleService()
    
    static var shared: PeopleService {
        return _sharedInstance
    }
    
    func index(callback: @escaping ([ Person ]) -> Void) {
        guard LocaleService.closest != nil else { return }
        
        RequestService.sharedInstance.request(relativeUrl: "/locales/\(LocaleService.closest!.id)/people") { (result) in
            let people = result["people"] as! [ [ String : Any ] ]
            var results: [ Person ] = []
            
            for person in people {
                results.append(Person(person))
            }
            
            callback(results)
        }
    }

}
