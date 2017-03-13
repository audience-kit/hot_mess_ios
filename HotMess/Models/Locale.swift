	//
//  Locale.swift
//  HotMess
//
//  Created by Rick Mark on 2/2/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class Locale : Model {
    let name: String
    
    override init(_ data: [ String : Any ]) {
        self.name = data["name"] as! String
        
        super.init(data)
    }
    
    init(id: UUID, name: String) {
        self.name = name
        
        super.init([ "id" : id.uuidString ])
    }
}
