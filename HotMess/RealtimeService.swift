//
// Created by Rick Mark on 3/18/17.
// Copyright (c) 2017 Hot Mess and Co. All rights reserved.
//

import Foundation
import Starscream
import Atlas

extension Notification.Name {
    static let inboundMessage = Notification.Name("InboundMessage")
}

class RealtimeService : WebSocketDelegate {


    private static var _shared: RealtimeService?

    let socket: WebSocket
    var conversation: VenueConversation?

    static var shared: RealtimeService {
        if _shared == nil {
            _shared = RealtimeService()
        }

        return _shared!
    }

    init() {

        self.socket = WebSocket(url: URL(string: "/connection", relativeTo: RequestService.shared.baseUrl)!)
        self.socket.delegate = self
    }

    func connect() {
        socket.connect()
    }

    func websocketDidConnect(socket: WebSocket) {
        print("websocket is connected")
    }

    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        print("websocket did disconnect \(error!)")
    }

    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        print("websocket received message \(text)")
        do {
            let parsed = try JSONSerialization.jsonObject(with: text.data(using: .utf8)!, options: JSONSerialization.ReadingOptions.allowFragments) as! [ String : Any ]
            
            if let message = parsed["message"] as? [ String : Any ] {
            

              
                conversation?.messageReceived(message: VenueMessage(data: message, conversation: RealtimeService.shared.conversation!))
                
            }
        }
        catch {
            
        }
    }

    func websocketDidReceiveData(socket: WebSocket, data: Data) {
        print("websocket receieved data \(data.description)")
    }
    
    func sendMessage(_ message: VenueMessage) {
        do {
            let identifier = [ "channel": "RealtimeChannel", "venue_id" : "chat_\(message.conversation.venue.id.uuidString)"]
            
            let identifierString = try String(data: JSONSerialization.data(withJSONObject: identifier, options: .prettyPrinted), encoding: .utf8)!
            
            let messageData = try JSONSerialization.data(withJSONObject: [ "command": "message", "identifier": identifierString, "data": message.toJson() ], options: .init(rawValue: 0))
            
            socket.write(string: String(bytes: messageData, encoding: .utf8)!)
        }
        catch {}
    }
    
    func subscribe(_ channel: String, other: [ String : Any ]? = nil) {
        do {
            var identifier = other ?? [:]
            identifier["channel"] = channel
            
            
            let identifierString = try String(data: JSONSerialization.data(withJSONObject: identifier, options: .prettyPrinted), encoding: .utf8)!
            let commandDictionary = [ "command": "subscribe", "identifier": identifierString ] as [String : Any]
            
            let messageData = try JSONSerialization.data(withJSONObject: commandDictionary, options: .init(rawValue: 0))
            
            socket.write(string: String(bytes: messageData, encoding: .utf8)!)
        }
        catch {}
    }
}
