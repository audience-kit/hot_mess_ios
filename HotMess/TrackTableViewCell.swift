//
//  TrackTableViewCell.swift
//  HotMess
//
//  Created by Rick Mark on 3/16/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class TrackTableViewCell : UITableViewCell {
    @IBOutlet var artworkImage: UIImageView?
    @IBOutlet var waveformImage: UIImageView?
    @IBOutlet var trackTitleView: UILabel?
    
    var linkUrl: URL?

    func setTrack(_ track: Track) {
        trackTitleView?.text = track.title
        artworkImage?.kf.setImage(with: track.artworkUrl)
        waveformImage?.kf.setImage(with: track.waveformUrl)
        
        linkUrl = track.providerUrl
    }
}
