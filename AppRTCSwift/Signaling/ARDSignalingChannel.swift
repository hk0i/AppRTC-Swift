//
// Created by Gregory McQuillan on 12/20/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import Foundation

enum ARDSignalingChannelState {
  /// disconnected
  case closed
  /// connection established, but not ready for use
  case open
  /// connection established and registered
  case registered
  /// connection encountered a fatal error
  case error
}

protocol ARDSignalingChannelDelegate: NSObjectProtocol {
  func channel(_ channel: ARDSignalingChannel,
               didChangeState state: ARDSignalingChannelState)

  func channel(_ channel: ARDSignalingChannel,
               didReceiveMessage message: ARDSignalingMessage)
}

protocol ARDSignalingChannel: NSObjectProtocol {
  var roomId: String { get }
  var clientId: String { get }
  var state: ARDSignalingChannelState { get }

  var delegate: ARDSignalingChannelDelegate? { get set }

  /// Registers the channel for the given room and client id
  func registerForRoom(withId roomId: String, clientId: String)

  /// Sends a signaling message over the channel
  func sendMessage(_ message: ARDSignalingMessage)
}
