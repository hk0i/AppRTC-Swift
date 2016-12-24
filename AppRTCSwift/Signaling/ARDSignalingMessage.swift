//
// Created by Gregory McQuillan on 12/20/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import WebRTC
import Foundation

enum ARDSignalingMessageType {
  case candidate
  case candidateRemoval
  case offer
  case answer
  case bye
}

class ARDSignalingMessage: NSObject {
  let type: ARDSignalingMessageType

  init(type: ARDSignalingMessageType) {
    self.type = type
  }

  static func messageFromJsonString(_ jsonString: String) {

  }

  func jsonData() -> NSData? {
    return nil
  }
}

class ARDICECandidateMessage: ARDSignalingMessage {
  let candidate: RTCIceCandidate

  init(candidate: RTCIceCandidate) {

  }
}

class ARDICECandidateRemovalMessage: ARDSignalingMessage {
  let candidates: [RTCIceCandidate]

  init(removedCandidates: [RTCIceCandidate]) {
  }
}

class ARDSessionDescriptionMessage: ARDSignalingMessage {
  let sessionDescription: RTCSessionDescription

  init(description: RTCSessionDescription) {
    self.sessionDescription = description
  }
}

class ARDByeMessage: ARDSignalingMessage {
  init() {

  }
}
