//
// Created by Gregory McQuillan on 12/23/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import Foundation

enum ARDJoinResultType {
  case unknown
  case success
  case full
}

class ARDJoinResponse {
  let result: ARDJoinResultType
  let isInitiator: Bool
  let roomId: String
  let clientId: String
  //todo: array of what?
  let messages: [ARDSignalingMessage]
  let webSocketUrl: URL
  let webSocketRestUrl: URL

  static func makeResponseFromJsonData(_ data: Data) -> ARDJoinResponse? {
    guard let responseJson = Dictionary(withJsonData: data) else {
      return nil
    }

    let resultString = responseJson[k.resultKey]
    //todo: assuming String:Any, but it's really JSON. I think
    let params: [String:Any] = responseJson[k.resultParamsKey]

    var isInitiator: Bool
    if let isInit = params[k.initiatorKey] as? Bool {
      isInitiator = isInit
    }
    else {
      // note: added default to false if could not cast
      isInitiator = false
    }

    let roomId = params[k.roomIdKey]
    let clientId = params[k.clientIdKey]

    // parse messages
    //todo: determine type
    var messages = [ARDSignalingMessage]()
    if let msgs = params[k.messagesKey] as? [ARDSignalingMessage] {
      // note: copying using map, iirc this copies references to the objects
      // for memory efficiency, however as soon as an object in the original
      // collection changes, a copy of the original is then made and it will
      // not alter the value in the new array.

      messages = msgs.map { $0 }
    } // unwrap of messages as array

    // parse websocket urls.

    var webSocketUrl: URL
    if let webSocketUrlString = params[k.webSocketUrlKey] as? String {
      //todo: not sure how to handle if there is no URL here
      webSocketUrl = URL(string: webSocketUrlString)!
    }

    var webSocketRestUrl: URL
    if let webSocketRestUrlString = params[k.webSocketRestUrlKey] as? String {
      //todo: not sure how to handle if there is no URL here
      webSocketRestUrl = URL(string: webSocketRestUrlString)!
    }

    let response = ARDJoinResponse(
        joinResult: ARDJoinResponse.makeResultTypeFromString(resultString),
        isInitiator: isInitiator,
        roomId: roomId,
        clientId: clientId,
        messages: messages,
        webSocketUrl: webSocketUrl,
        webSocketRestUrl: webSocketRestUrl)

    return response
  }

  // From implementation

  private struct k {
    static let resultKey = "result"
    static let resultParamsKey = "resultParamsKey"
    static let initiatorKey = "is_initiator"
    static let roomIdKey = "room_id"
    static let clientIdKey = "client_id"
    static let messagesKey = "messages"
    static let webSocketUrlKey = "wss_url"
    static let webSocketRestUrlKey = "wss_post_url"
  }

  // MARK - Private

  private static func makeResultTypeFromString(_ resultString: String)
          -> ARDJoinResultType {
    switch resultString {

      case "SUCCESS":
        return .success

      case "FULL":
        return .full

      default:
        return ARDJoinResultType.unknown

    }
  } // makeResultTypeFromString

  //note: this is an adaption to the original, making all parameters required
  // at initialization for immutability's sake, may have to change this later.
  init(joinResult result: ARDJoinResultType,
       isInitiator: Bool,
       roomId: String,
       clientId: String,
      //todo: figure out type
       messages: [ARDSignalingMessage]?,
       webSocketUrl: URL,
       webSocketRestUrl: URL) {

    self.result = result
    self.isInitiator = isInitiator
    self.roomId = roomId
    self.clientId = clientId
    self.messages = messages ?? [ARDSignalingMessage]()
    self.webSocketUrl = webSocketUrl
    self.webSocketRestUrl = webSocketRestUrl
  }
}
