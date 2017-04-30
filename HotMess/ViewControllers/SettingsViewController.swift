//
//  SettingsViewController.swift
//  HotMess
//
//  Created by Rick Mark on 2/15/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import UIKit
import FacebookCore
import FacebookLogin
import FBSDKLoginKit
import MessageUI
import Kingfisher


class SettingsViewController : UITableViewController, MFMailComposeViewControllerDelegate {
    @IBOutlet var profileImage: FBSDKProfilePictureView?
    @IBOutlet var nameLabel: UILabel?
    
    var environmentSheet: UIAlertController?
    
    override func awakeFromNib() {
        if let userProfileImage = self.profileImage {
            userProfileImage.pictureMode = .square
            userProfileImage.setNeedsImageUpdate()
        }
        
        NotificationCenter.default.addObserver(forName: SessionService.LoginSuccess, object: self, queue: OperationQueue.main) { _ in
            self.tableView.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        SessionService.me { (user) in
            DispatchQueue.main.async {
                self.nameLabel?.text = user.name
            }
        }
        
        let mask = CAShapeLayer()
        
        mask.fillColor = UIColor.black.cgColor
        mask.path = UIBezierPath(ovalIn: CGRect(origin: CGPoint.zero, size: profileImage!.frame.size)).cgPath
        
        profileImage!.layer.mask = mask
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return 3
        case 2:
            return 2
        default:
            return 0
        }
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            if MFMailComposeViewController.canSendMail() {
                let composeView = MFMailComposeViewController()
                
                composeView.setToRecipients(["feedback@hotmess.social"])
                composeView.setSubject("Hot Mess: Feedback")
                composeView.mailComposeDelegate = self
                
                self.present(composeView, animated: true, completion: nil)
            }
            else {
                let alertController = UIAlertController(title: "Feedback", message: "Unable to send feedback email.  Ensure that an account is configured or email feedback@hotmess.social from your computer.", preferredStyle: .alert)
                
                alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default, handler: { (action) in
                   alertController.dismiss(animated: true, completion: nil)
                }))
                    
                self.present(alertController, animated: true, completion: nil)
            }
        }
        else if indexPath.section == 2 {
            switch indexPath.row {
            case 0:
                if let bundle = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: bundle)
                }
                UserDefaults.standard.synchronize()
                ImageCache.default.clearDiskCache()
                ImageCache.default.clearMemoryCache()
            case 1:
                SessionService.logOut()
                FBSDKAccessToken.setCurrent(nil)
                SessionService.me() { _ in
                    
                }
            default:
                break
            }
        }
    }
    
    func setEnvironment(appId : String) {
        UserDefaults.standard.set(appId, forKey: "facebook_app_id")
        UserDefaults.standard.synchronize()
        
        self.environmentSheet?.dismiss(animated: true, completion: nil)
        
        SessionService.logOut()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let feedbackButton = tableView.dequeueReusableCell(withIdentifier: "settingButtonCell")
            
            feedbackButton?.textLabel?.text = "Submit Feedback"
            feedbackButton?.textLabel?.textAlignment = .center
            feedbackButton?.textLabel?.textColor = UIColor.blue
            
            return feedbackButton!
        }
        
        if indexPath.section == 1 {
            let settingsDetailRow = tableView.dequeueReusableCell(withIdentifier: "settingCell")!
            settingsDetailRow.textLabel?.textColor = UIColor.gray
            
            switch indexPath.row {
            case 0:
                let info = Bundle.main.infoDictionary!
                
                settingsDetailRow.textLabel?.text = "version"
                settingsDetailRow.detailTextLabel?.text = "\(info["CFBundleShortVersionString"]!) (\(info["CFBundleVersion"]!))"
            case 1:
                _ = Bundle.main.infoDictionary!
                
                settingsDetailRow.textLabel?.text = "facebook"
                settingsDetailRow.detailTextLabel?.text = self.facebookEnvironment
            case 2:
                let server = RequestService.shared.baseUrl
                
                settingsDetailRow.textLabel?.text = "server"
                settingsDetailRow.detailTextLabel?.text = server.absoluteString
            default:
                settingsDetailRow.textLabel?.text = "invalid"
            }
            
            return settingsDetailRow
        }
        
        let settingsButton = tableView.dequeueReusableCell(withIdentifier: "settingButtonCell")
        settingsButton?.textLabel?.textAlignment = .center
        settingsButton?.textLabel?.textColor = UIColor.red
        
        switch indexPath.row {
        case 0:
            
            settingsButton?.textLabel?.text = "Reset All Data"
        case 1:
            settingsButton?.textLabel?.text = "Sign Out"
        default: break
            
        }
        
        return settingsButton!
    }
    
    private var facebookEnvironment : String {
        switch Bundle.main.infoDictionary!["FacebookAppID"] as! String {
        case "713525445368431":
            return "production"
        case "915436455177328":
            return "staging"
        case "842337999153841":
            return "development"
        default:
            return "unknown"
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
