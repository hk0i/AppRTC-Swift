//
// Created by Gregory McQuillan on 12/20/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import Foundation

enum ARDSignalingChannelState {
  case closed
  case open
  case registered
  case error
}

protocol ARDSignalingChannelDelegate: NSObjectProtocol {
  func channel(_ channel: ARDSignalingChannel,
               didChangeState state: ARDSignalingChannelState)

  func channel(_ channel: ARDSignalingChannel,
               didReceiveMessage message: ARDSignalingMessage)
}

class ARDSignalingChannel {
  //todo: update type, finish implementing this class
  var state: Any
}
