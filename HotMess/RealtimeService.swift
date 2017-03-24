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
        print("websocket did disconnect \(error)")
    }

    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        print("websocket received message \(text)")
        conversation?.messageReceived(message: VenueMessage(message: text))
    }

    func websocketDidReceiveData(socket: WebSocket, data: Data) {
        print("websocket receieved data")
    }
    
    func sendMessage(_ message: VenueMessage) {
        socket.write(string: message.toJson())
    }
}
