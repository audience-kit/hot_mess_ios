//
//  FriendLisetTableViewCell.swift
//  HotMess
//
//  Created by Rick Mark on 3/20/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit

class FriendListTableViewCell : UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    @IBOutlet var userCollectionView : UICollectionView?
    
    private var friends = [ Friend ]()
    
    func setFriends(_ friends : [ Friend ]) {
        self.friends = friends
        
    
        userCollectionView?.reloadData()
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "personCell", for: indexPath) as! PersonCell
        
        cell.setPerson(friends[indexPath.row])
        
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.friends.count
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        UIApplication.shared.open(self.friends[indexPath.row].messengerUrl, options: [:], completionHandler: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
}
