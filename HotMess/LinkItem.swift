//
//  LinkItem.swift
//  HotMess
//
//  Created by Rick Mark on 5/16/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class LinkItem : ListingItem {
    var cellType: String { get { return "linkCell" } }
    
    let url: URL
    let imageUrl: URL
    let height: Int
    
    init(_ data: [ String : Any ]) {
        self.url = URL(string: data["url"] as! String)!
        self.imageUrl = URL(string: data["image_url"] as! String)!
        self.height = data["height"] as! Int
    }
}
