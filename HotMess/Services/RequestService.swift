//
//  RequestService.swift
//  HotMess
//
//  Created by Rick Mark on 1/3/17.
//  Copyright © 2017 Hot Mess and Co. All rights reserved.
//

import Foundation
import Locksmith
import FacebookLogin

class RequestService
{
    private static let sharedInstance = RequestService()
    
    private var _isAuthenticating = false
    
    
    var baseUrl: URL {
        let appId = UserDefaults.standard.string(forKey: "facebook_app_id") ?? ""

        switch appId {
        case "842337999153841":
            return URL(string: "http://localhost:3000")!
        case "915436455177328":
                return URL(string: "https://next-api.hotmess.social")!
        default:
            return URL(string: "https://api.hotmess.social")!
        }
    }

    public static var shared: RequestService {
        return RequestService.sharedInstance
    }
    
    func request(relativeUrl: String, _ callback : @escaping ([String: Any]) -> Void) {
        return self.request(DataRequest(relativeUrl, parameters: nil, callback: callback))
    }
    
    func request(relativeUrl: String, with: [String: Any]?, _ callback : @escaping ([String: Any]) -> Void) {
        return self.request(DataRequest(relativeUrl, parameters: with, callback: callback))
    }
    
    func request(_ dataRequest: DataRequest) {
        let url = URL(string: dataRequest.path, relativeTo: self.baseUrl)
        
        var request = URLRequest(url: url!)
        
        do {
            if let account = SessionService.token {
                request.addValue("Bearer \(account)", forHTTPHeaderField: "Authorization")
            }
            
            if (dataRequest.parameters != nil) {
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: dataRequest.parameters!, options: .prettyPrinted)
            }
            else {
                request.httpMethod = "GET"
            }
            
            NSLog("\(request.httpMethod!): \(request.url!)")
            
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                if let error = error {
                    NSLog(error.localizedDescription)
                }
                
                let httpResponse = response as? HTTPURLResponse
                
                if httpResponse == nil {
                    let alert = UIAlertController(title: "Error", message: "Unable to reach server. Check network connection.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: .default))
                    
                    DispatchQueue.main.async {
                        alert.show(UIApplication.shared.keyWindow!.rootViewController!, sender: self)
                    }
                    
                    return
                }
                
                if (httpResponse!.statusCode == 401)
                {
                    if (self._isAuthenticating == false) {
                        self._isAuthenticating = true
                        SessionService.logOut()
                        NotificationCenter.default.post(name: SessionService.loginRequired, object: self)
                    }
                    
                    return
                }
                
                self._isAuthenticating = false
                
                let data = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! [ String: Any]
                
                if data != nil {
                    dataRequest.callback!(data!)
                }
            })
            
            task.resume()
        }
        catch {
            dataRequest.callback!([:])
        }
        
    }
}


