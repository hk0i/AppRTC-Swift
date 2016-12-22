//
// Created by Gregory McQuillan on 12/21/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import Foundation

protocol ARDRoomServerClient: NSObjectProtocol {

  // note: blocks converted to typealias for readability
  typealias JoinHandler = (ARDJoinResponse, Error?) -> ()
  typealias SendMessageHandler = (ARDMessageResponse, Error?) -> ()
  typealias GenericHandler = (Error?) -> ()

  func joinRoom(roomId: String,
                isLoopback: Bool,
                completionHandler: JoinHandler?)

  func sendMessage(_ message: ARDSignalingMessage,
                   roomId: String,
                   clientId: String,
                   completionHandler: SendMessageHandler?)

  func leaveRoom(roomId: String, clientId: String,
                 completionHandler: GenericHandler?)

}
