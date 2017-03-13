//
//  SocialLink.swift
//  HotMess
//
//  Created by Rick Mark on 3/13/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class SocialLink : Model {
    let handle: String
    let provider: String
    var url: URL
    
    override init(_ data: [ String : Any ]) {
        self.handle = data["handle"] as! String
        self.provider = data["provider"] as! String
        self.url = URL(string: data["url"] as! String)!
        
        super.init(data)
    }
}
