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
    let waveformUrl: URL
    let artworkUrl: URL
    // TODO: Released at, damn DateFormatter
    
    override init(_ data: [ String : Any ]) {
        self.title = data["title"] as! String
        self.provider = data["provider"] as! String
        self.providerUrl = URL(string: data["provider_url"] as! String)!
        
        self.artworkUrl = URL(string: data["artwork_url"] as! String)!
        self.waveformUrl = URL(string: data["waveform_url"] as! String)!
        
        super.init(data)
    }
}
