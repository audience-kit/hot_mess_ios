//
//  Track.swift
//  HotMess
//
//  Created by Rick Mark on 3/13/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class Track : Model {
    let title: String
    let provider: String
    let providerUrl: URL
    // TODO: Released at, damn DateFormatter
    
    override init(_ data: [ String : Any ]) {
        self.title = data["title"] as! String
        self.provider = data["provider"] as! String
        self.providerUrl = URL(string: data["provider_url"] as! String)!
        
        super.init(data)
    }
}
