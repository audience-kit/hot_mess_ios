//
//  Model.swift
//  HotMess
//
//  Created by Rick Mark on 3/1/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class Model : NSObject {
    let id: UUID
    
    init(_ data: [ String : Any ]) {
        self.id = UUID(uuidString: data["id"] as! String)!
    }
}
