//
// Created by Gregory McQuillan on 12/21/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import Foundation
import WebRTC

protocol ARDTurnClient {
  typealias TurnCompletionHandler = ([RTCIceServer], Error?) -> ()
  func requestServers(completionHandler: TurnCompletionHandler?)
}
