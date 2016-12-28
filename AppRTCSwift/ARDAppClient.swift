//
// Created by Gregory McQuillan on 12/19/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import WebRTC
import Foundation

enum ARDAppClientState {
  case disconnected
  case connecting
  case connected
}

/**
 * The delegate is informed of pertinent events and will be called on the main
 * queue
 */
protocol ARDAppClientDelegate: NSObjectProtocol {
  func appClient(_ client: ARDAppClient,
                 didChangeState: ARDAppClientState)

  func appClient(_ client: ARDAppClient,
                 didChangeConnectionState: RTCIceConnectionState)

  func appClient(_ client: ARDAppClient,
                 didReceiveLocalVideoTrack: RTCVideoTrack)

  func appClient(_ client: ARDAppClient,
                 didReceiveRemoteVideoTrack: RTCVideoTrack)

  func appClient(_ client: ARDAppClient,
                 didError: Error)

  func appClient(_ client: ARDAppClient,
                 didGetStats: [RTCLegacyStatsReport])
}

/**
 * We need a proxy to NSTimer because it causes a strong retain cycle.
 * When using the proxy `invalidate` must be called before it properly
 * deallocs.
 *
 * Note: This was in the original implementation, not sure if this holds
 * true to Swift as well - GM
 */
class ARDTimerProxy: NSObject {

  typealias TimerHandler = (() -> ())
  private let _timer: Timer
  private let _timerHandler: TimerHandler

  init(interval: TimeInterval, repeats: Bool,
      timerHandler: @escaping TimerHandler) {
    // note: removed NSParameterAssert(), it does not exist in swift and is not
    // needed since the TimerHandler has been set to a non-optional parameter.
    // Also made the closure escaping because it is not immediately invoked.
    super.init()
    self._timerHandler = timerHandler
    self._timer = Timer(timeInterval: interval, target: self,
        selector: #selector(timerDidFire), userInfo: nil, repeats: repeats)
  }

  func invalidate() {
    self._timer.invalidate()
  }

  func timerDidFire(timer: Timer) {
    self._timerHandler()
  }
}

/**
 * Handles connections to the AppRTC Server for a given room.
 * Methods on this class should only be called from the main queue.
 */
class ARDAppClient: NSObject {

  // MARK: - Private constants from implementation file (.m)

  // note: removed some of the prefixes to shorten the constant names since
  // they will all get namespaced by `ARDAppClient`

  private let kDefaultSTUNServerUrl = "stun:stun.1.google.com:19302"
  private let kTurnRequestUrl = "https://computerengineondemand.appspot.com"
      + "/turn?username=iapprtc&key=4080218913"


  fileprivate static let kErrorDomain = "ARDAppClient"
  // note: converted to enum to reduce typing and improve readability (hopefully)
  fileprivate enum kClientError: Int {
    case unknown = -1
    case roomFull = -2
    case createSDP = -3
    case setSDP = -4
    case invalidClient = -5
    case invalidRoom = -6
  }

  private static let kMediaStreamId = "ARDAMS"
  private static let kAudioTrackId = "ARDAMSa0"
  private static let kVideoTrackId = "ARDAMSv0"

  private static let kEnableTracing = false
  private static let kEnableRtcEventLog = false
  private static let kAecDumpMaxSizeInBytes = 5e6 // 5MB
  private static let kRtcEventLogMaxSizeInBytes = 5e6 // 5MB

  // MARK - From Defaults section originally

  // note: cameraConstraints set below

  // note: converted from an accessor method to a computed property
  fileprivate var defaultAnswerConstraints: RTCMediaConstraints {
    get {
      return self.defaultOfferConstraints
    }
  }

  private var defaultOfferConstraints: RTCMediaConstraints {
    get {
      let mandatoryConstraints = [
          "OfferToReceiveAudio": "true",
          "OfferToReceiveVideo": "true"
      ]

      return RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints,
          optionalConstraints: nil)
    }
  }

  private var defaultPeerConnectionConstraints: RTCMediaConstraints {
    get {
      let value = self.isLoopback ? "false" : "true"
      let optionalConstraints = [
        "DtlsSrtpKeyAgreement": value
      ]

      return RTCMediaConstraints(mandatoryConstraints: nil,
          optionalConstraints: optionalConstraints)
    }
  }

  private var defaultStunServer: RTCIceServer {
    get {
      return RTCIceServer(urlStrings: [kDefaultSTUNServerUrl],
          username: "", credential: "")
    }
  }

  // MARK: iVars from @implementation in implementation (.m)
  private var _fileLogger: RTCFileLogger?
  private var _statsTimer: ARDTimerProxy
  var cameraConstraints: RTCMediaConstraints

  // MARK: properties/methods from `ARDAppClient+Internal.h`

  // all properties should only be mutated from the main queue
  internal var roomServerClient: ARDRoomServerClient?
  internal var channel: ARDSignalingChannel?
  internal var loopbackChannel: ARDSignalingChannel?
  internal var turnClient: ARDTurnClient?

  // note: underscore added to avoid name collision with delegate functions.
  internal var _peerConnection: RTCPeerConnection?
  internal var factory: RTCPeerConnectionFactory?
  // todo: verify type of this array (?) Declared as `NSMutableArray`
  //       originally.
  internal var messageQueue: [ARDSignalingMessage] = []

  internal var isTurnComplete: Bool
  internal var hasReceivedSdp: Bool
  internal var hasJoinedRoomServerRoom: Bool {
    get {
      //note: converted from accessor method
      //if we have a client id, we have connected.
      return !self.clientId.isEmpty
    }
  }

  internal var roomId: String
  internal var clientId: String
  internal var isInitiator: Bool
  // todo: make sure this is an RTCIceServer array
  internal var iceServers: [RTCIceServer]
  internal var webSocketUrl: URL
  internal var webSocketRestUrl: URL
  internal var isLoopback: Bool
  internal var isAudioOnly: Bool
  internal var shouldMakeAecDump: Bool
  internal var shouldUseLevelControl: Bool

  // MARK: - Public / From  Header

  /**
   * If `true`, stats will be reported in 1 second intervals through the
   * delegate.
   * note: Converted to a *computed property.*
   */
  var shouldGetStats: Bool {
    // note: converted from mutator method
    willSet(newShouldGetStats) {
      if shouldGetStats == newShouldGetStats {
        return
      }

      if shouldGetStats {
        self._statsTimer = ARDTimerProxy(interval: 1, repeats: true) {          [weak self] in

          if let strongSelf = self {
            strongSelf._peerConnection?.stats(for: nil, statsOutputLevel: .debug)
            { (stats: [RTCLegacyStatsReport]) in
              DispatchQueue.main.async {
                strongSelf.delegate?.appClient(strongSelf, didGetStats: stats)
              }
            }
          }
        }
      }
      else {
        // should not get stats :)
        self._statsTimer.invalidate()
        // note: removed because it's non-optional.
//        self._statsTimer = nil
      }
    } // shouldGetStats: willSet
  }

  var state: ARDAppClientState {
    // note: converted from mutator method
    willSet(newState) {
      if (state == newState) { return }
      self.delegate?.appClient(self, didChangeState: newState)
    }
  }

  var delegate: ARDAppClientDelegate?

  /**
   * Convenience constructor since all expected use cases will need a delegate
   * in order to receive remote tracks.
   */
  convenience init (delegate: ARDAppClientDelegate) {
    self.delegate = delegate
    self.commonDefaultTurnInit()
  }

  /**
   * Establishes a connection with the AppRTC servers for the given `roomId`.
   * If `isLoopback` is `true`, the call will connect to itself.
   * If `isAudioOnly` is `true`, video will be disabled for the call
   * If `shouldMakeAecDump` is `true` an aecdump will be created for the call.
   * If `shouldUseLevelControl` is `true`, the level controller wil be used in
   *    the call.
   */
  func connectToRoom(roomId: String,
      isLoopback: Bool,
      isAudioOnly: Bool,
      shouldMakeAecDump: Bool,
      shouldUseLevelControl: Bool) {
    assert(!roomId.isEmpty, "Room id cannot be empty")
    assert(self.state == ARDAppClientState.disconnected,
        "Shouldn't be connected...")

    self.isLoopback = isLoopback
    self.isAudioOnly = isAudioOnly
    self.shouldMakeAecDump = shouldMakeAecDump
    self.shouldUseLevelControl = shouldUseLevelControl

    self.state = .connecting

    #if WEBRTC_IOS
    if kEnableTracing {
      let filePath = self.documentsFilePath(fileName: "webrtc-trace.txt")
      RTCStartInternalCapture(filePath)
    }
    #endif

    // request turn
    turnClient?.requestServers() {
        [weak self] (turnServers: [RTCIceServer], error: Error?) in

      if let err = error {
        RTCLogEx(.error, "Error retrieving TURN servers, "
            + "\(err.localizedDescription)")
      }

      if let strongSelf = self {
        strongSelf.iceServers.append(contentsOf: turnServers)
        strongSelf.isTurnComplete = true
        strongSelf.startSignalingIfReady()
      }
    }

    // join room on server
    self.roomServerClient?.joinRoom(roomId: roomId, isLoopback: isLoopback) {
        [weak self]
        (response: ARDJoinResponse, error: Error?) in

      guard let strongSelf = self else { return }

      if let err = error {
        strongSelf.delegate?.appClient(strongSelf, didError: err)
        return
      }

      let selfType = type(of: strongSelf)
      if let joinError = selfType.error(forMessageResultType: response.result) {
        RTCLogEx(.error, "Failed to join room: \(roomId)")
        strongSelf.disconnect()
        strongSelf.delegate?.appClient(strongSelf, didError: joinError)
        return
      }

      RTCLogEx(.info, "Joined room: \(roomId)")
      strongSelf.roomId = response.roomId
      strongSelf.clientId = response.clientId
      strongSelf.isInitiator = response.isInitiator

      for message in response.messages {
        if message.type == .offer || message.type == .answer {
          strongSelf.hasReceivedSdp = true
          strongSelf.messageQueue.insert(message, at: 0)
        }
        else {
          strongSelf.messageQueue.append(message)
        }
      } // for message in messages

      strongSelf.webSocketUrl = response.webSocketUrl
      strongSelf.webSocketRestUrl = response.webSocketRestUrl
      strongSelf.registerWithColliderIfReady()
      strongSelf.startSignalingIfReady()
    }
  } // connectToRoomWithId:

  /**
   * Disconnects from the AppRTC servers and any connected clients.
   */
  func disconnect() {
    if self.state == .disconnected {
      return
    }

    if self.hasJoinedRoomServerRoom {
      self.roomServerClient?.leaveRoom(roomId: self.roomId,
          clientId: self.clientId) { (error: Error?) in

      }
    }

    if let channel = self.channel {
      if channel.state == .registered {
        // tell the other client we're hanging up
        let byeMessage = ARDByeMessage()
        channel.sendMessage(byeMessage)
      }

      // disconnect from collider
      self.channel = nil
    } // unwrap self.channel

    //todo: these were set to nil originally, may need to make them optional
    self.clientId = ""
    self.roomId = ""
    self.isInitiator = false
    self.hasReceivedSdp = false
    self.messageQueue = []

    #if WEBRTC_IOS
    self.factory.stopAecDump()
    self._peerConnection.stopRtcEventLog()
    #endif

    self._peerConnection = nil
    self.state = .disconnected

    #if WEBRTC_IOS
    RTCStopInternalCapture()
    #endif
  } // disconnect()

  // MARK: - Implementation functions

  override init() {
    super.init()
    self.commonDefaultTurnInit()
  }

  /**
   * Common init function added in Swift conversion to reduce code duplication.
   * Sets up `roomServerClient` and `turnClient` then calls `configure()`
   */
  func commonDefaultTurnInit() {
    self.roomServerClient = ARDAppEngineClient()

    let turnRequestUrl = URL(string: kTurnRequestUrl)
    self.turnClient = ARDCEODTURNClient(URL: turnRequestUrl)
  }

  init(roomServerClient rsClient: ARDRoomServerClient,
       signalingChannel channel: ARDSignalingChannel,
       turnClient: ARDTurnClient,
       delegate: ARDAppClientDelegate) {
    // note: assertions removed since these parameters are non-optional.
    self.roomServerClient = rsClient
    self.channel = channel
    self.turnClient = turnClient
    self.delegate = delegate
    //note: removed configure()... I think
    //self.configure()
    // note: does not need to call `commonDefaultTurnInit()`: `turnClient` is
    // already provided.
  }

  // note: this is the Swift equivalent of the objc `dealloc()`
  deinit {
    self.shouldGetStats = false
    self.disconnect()
  }

  // note: setState and setShouldGetStats are now implemented as `willSet`s

  // MARK - Private

#if WEBRTC_IOS
  func documentsFilePath(forFile fileName: String) {
    assert(!fileName.isEmpty, "File name cannot be empty")
    let paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
        NSUserDomainMask, true)
    let documentsDirPath = paths[0]
    let filePath = documentsDirPath.stringByAppendingPathComponent(fileName)

    return filePath
  }
#endif

  // note: `hasJoinedRoomServerRoom` accessor is now a computed { get }

  /**
   * Begins the peer connection connection process if both users have joined a
   * room on the room server and tried to obtain a TURN server. Otherwise does
   * nothing.
   *
   * A peer connection object will be created with a stream that contains local
   * audio and video capture. If this client is the caller, an offer is created
   * as well, otherwise the client will wait for an offer to arrive.
   */
  func startSignalingIfReady() {
    if !self.isTurnComplete || !self.hasJoinedRoomServerRoom {
      return
    }

    self.state = .connected

    // create peer connection
    let constraints = self.defaultPeerConnectionConstraints
    let config = RTCConfiguration()
    config.iceServers = self.iceServers
    self._peerConnection = self.factory?.peerConnection(with: config,
        constraints: constraints, delegate: self)

    // create AV senders
    // note: return value was never used in original call.
    //       assigning to `_` to clarify this is intentional.
    _ = self.createAudioSender()
    _ = self.createVideoSender()

    if self.isInitiator {
      // send offer
      self._peerConnection?.offer(for: self.defaultOfferConstraints) {
          [weak self] sessionDescription, error in
        if let strongSelf = self,
            let connection = strongSelf._peerConnection,
            let description = sessionDescription {

          strongSelf.peerConnection(connection,
              didCreate: description, error: error)
        }
      }
    }
    else {
      // is not initiator, check if we've received an offer
      self.drainMessageQueueIfReady()
    }

    #if WEBRTC_IOS
    //start event log
    if (kEnableRtcEventLog) {
      let filePath = self.documentsFilePath(forFile: "webrtc-rtceventlog")
      if !self._peerConnection.startRtcEventLog(withFilePath: filePath,
          maxSizeInBytes: kRtcEventLogMaxSizeInBytes) {
        RTCLogEx(.error, "Failed to start event logging")
      }
    }

    // start aecdump diagnostic recording
    if shouldMakeAecDump {
      let filePath = self.documentsFilePath(forFile: "webrtc-audio.aecdump")
      if !self.factory.startAecDump(withFilePath: filePath,
          maxSizeInBytes: kAecDumpMaxSizeInBytes) {
        RTCLogEx(.error, "Failed to start aec dump")
      }
    }
    #endif
  } // startSignalingIfReady

  /**
   * Processes the messages that we've received from the room server and the
   * signaling channel. The offer or answer message must be processed before
   * other signaling messages, however they can arrive out of order. Hence, this
   * method only processes pending messages if there is a peer connection object
   * and if we have received either an offer or an answer.
   */
  func drainMessageQueueIfReady() {
    // note: converted to nil check
    if self._peerConnection == nil || !self.hasReceivedSdp {
      return
    }

    for message in messageQueue {
      self.processSignalingMessage(message)
    }

    self.messageQueue.removeAll()
  }

  /// Processes the given signaling message based on its type.
  func processSignalingMessage(_ message: ARDSignalingMessage) {
    assert(self._peerConnection != nil, "peer connection cannot be nil")
    assert(message.type != .bye, "Signaling type cannot be Bye")

    switch message.type {
      case .offer: fallthrough
      case .answer:
        if let sdpMessage = message as? ARDSessionDescriptionMessage {
          let description = sdpMessage.sessionDescription
          let sdpPreferringH264 = ARDSDPUtils.makeDescriptionFor(
              description: description, preferringVideoCodec: "H264")

          self._peerConnection?.setRemoteDescription(sdpPreferringH264) {
              [weak self] error in
            if let strongSelf = self,
                let peerConnection = strongSelf._peerConnection {
              strongSelf.peerConnection(peerConnection,
                  didSetSessionDescriptionWithError: error)
            }
          }
        } // sdpMessage as ARDSessionDescriptionMessage, .answer

      case .candidate:
        if let candidateMessage = message as? ARDICECandidateMessage {
          self._peerConnection?.add(candidateMessage.candidate)
        }

      case .candidateRemoval:
        if let candidateMessage = message as? ARDICECandidateRemovalMessage {
          self._peerConnection?.remove(candidateMessage.candidates)
        }

      case .bye:
        // other client disconnected
        self.disconnect()
    }
  } // processSignalingMessage


  /**
   * Sends a signaling message to the other client.
   * The caller will send messages through the room server, whereas the
   * callee will send messages over the signaling channel.
   */
  func sendSignalingMessage(_ message: ARDSignalingMessage) {
    if self.isInitiator {
      self.roomServerClient?.sendMessage(message,
          roomId: self.roomId,
          clientId: self.clientId) { [weak self] response, error in

        // save indentation by using guard instead of if let
        guard let strongSelf = self else { return }

        if let err = error {
          strongSelf.delegate.appClient(strongSelf, didError: err)
          return
        }

        let messageError = type(of: strongSelf)
            .errorForMessageResultType(resposne.result)
        if let messageError = messageError {
          strongSelf.delegate(strongSelf, didError: messageError)
          return
        }
      }
    }
    else {
      // if is not initiator
      self.channel?.sendMessage(message)
    }
  } // sendSignalingMessage()

  func createVideoSender() -> RTCRtpSender? {
    let sender = self._peerConnection?.sender(
        withKind: kRTCMediaStreamTrackKindVideo,
        streamId: ARDAppClient.kMediaStreamId)

    if let track = self.createLocalVideoTrack() {
      sender?.track = track
      self.delegate?.appClient(self, didReceiveLocalVideoTrack: track)
    }

    return sender
  }

  func createAudioSender() -> RTCRtpSender? {
    let constraints = self.defaultMediaAudioConstraints()
    var sender: RTCRtpSender?
    if let source = self.factory?.audioSource(with: constraints) {
      let track = self.factory?.audioTrack(with: source,
          trackId: ARDAppClient.kAudioTrackId)

      sender = self._peerConnection?.sender(
          withKind: kRTCMediaStreamTrackKindAudio,
          streamId: ARDAppClient.kMediaStreamId)

      sender?.track = track

    }

    return sender
  }

  func createLocalVideoTrack() -> RTCVideoTrack? {
    let localVideoTrack: RTCVideoTrack?
    // the iOS simulator doesn't provide any sort of camera capture support
    // or emulation (http://goo.gl/rHAnC1) so don't bother trying to open a
    // local stream

    //note: this is a change from #if !TARGET_IPHONE_SIMULATOR.
    //see: http://stackoverflow.com/questions/24869481/detect-if-app-is-being-built-for-device-or-simulator-in-swift
#if !((arch(i386) || arch(x86_64)) && os(iOS))
    if (!self.isAudioOnly) {
      let cameraConstraints = self.cameraConstraints
      let source = self.factory?.avFoundationVideoSource(with: cameraConstraints)
      let localVideoTrack = self.factory.videoTrack(with: source,
          trackId: kVideoTrackId)
    }
#endif

    return localVideoTrack
  } // createLocalVideoTrack()

  // MARK: - Collider methods

  func registerWithColliderIfReady() {
    if !self.hasJoinedRoomServerRoom {
      return
    }

    // open websocket connection
    if self.channel == nil {
      self.channel = ARDWebSocketChannel(url: self.webSocketUrl,
          restUrl: self.webSocketRestUrl,
          delegate: self)

      if self.isLoopback {
        self.loopbackChannel = ARDLoopbackWebSocketChannel(
            url: self.webSocketUrl, restUrl: self.webSocketRestUrl)
      }
    }

    self.channel?.registerForRoom(withId: self.roomId, clientId: self.clientId)
    if self.isLoopback {
      self.loopbackChannel?.registerForRoom(withId: self.roomId,
          clientId: self.clientId)
    }
  } // registerWithColliderIfReady()

  // MARK - Defaults

  func defaultMediaAudioConstraints() -> RTCMediaConstraints {
    let valueLevelControl = self.shouldUseLevelControl ? kRTCMediaConstraintsValueTrue : kRTCMediaConstraintsValueFalse

    let mandatoryConstraints = [
        kRTCMediaConstraintsLevelControl: valueLevelControl
    ]

    let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints,
        optionalConstraints: nil)

    return constraints
  } // defaultMediaAudioConstraints

  // note: most getters were changed to constant `let` properties

  // MARK - Errors

  private static func error(forMessageResultType resultType: ARDJoinResultType) -> NSError? {
    var error: NSError?
    switch resultType {

      case .unknown:
        error = NSError(domain: ARDAppClient.kErrorDomain,
            code: kClientError.unknown.rawValue,
            userInfo: [
              NSLocalizedDescriptionKey: "Unknown error."
            ])

      case .full:
        error = NSError(domain: ARDAppClient.kErrorDomain,
            code: kClientError.roomFull.rawValue,
            userInfo: [
              NSLocalizedDescriptionKey: "Room is full."
            ])
      
    case .success: fallthrough
    default:
      break
    } // switch

    return error
  } // error(messageResultType:)

} // ARDAppClient

// MARK: - ARDSignalingChannelDelegate

extension ARDAppClient: ARDSignalingChannelDelegate {
  func channel(_ channel: ARDSignalingChannel,
               didReceiveMessage message: ARDSignalingMessage) {
    switch message.type {
      case .offer: fallthrough
      case .answer:
        //offers and answers must be processed before any other message, so we
        // place them at the front of the queue
        self.hasReceivedSdp = true
        self.messageQueue.insert(message, at: 0)

      case .candidate: fallthrough
      case .candidateRemoval:
        self.messageQueue.append(message)

      case .bye:
        self.processSignalingMessage(message)

    }

    self.drainMessageQueueIfReady()
  } // channel(_:didReceiveMessage:)

  func channel(_ channel: ARDSignalingChannel,
               didChangeState state: ARDSignalingChannelState) {

    switch state {
      case .open: fallthrough
      case .registered:
        break

      case .closed: fallthrough
      case .error:
        self.disconnect()
    }
  } // channel(_:didChangeState:)

} // ARDSignalingChannelDelegate

// MARK: -

extension ARDAppClient: RTCPeerConnectionDelegate {
  func peerConnection(_ peerConnection: RTCPeerConnection,
                      didChange stateChanged: RTCSignalingState) {
    RTCLogEx(.verbose, "Signaling state changed: \(stateChanged)")
  }

  func peerConnection(_ peerConnection: RTCPeerConnection,
                      didAdd stream: RTCMediaStream) {
    DispatchQueue.main.async {
      RTCLogEx(.verbose, String(format: "Received %d video tracks and %d " +
          "audio tracks", stream.videoTracks.count, stream.audioTracks.count))

      if (stream.videoTracks.count > 0) {
        let videoTrack = stream.videoTracks[0]
        self.delegate?.appClient(self, didReceiveRemoteVideoTrack: videoTrack)
      }
    } // main queue
  }

  func peerConnection(_ peerConnection: RTCPeerConnection,
                      didRemove stream: RTCMediaStream) {
    RTCLogEx(.verbose, "Stream was removed")
  }

  func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
    RTCLogEx(.warning, "Renegotiation needed but not implemented")
  }

  func peerConnection(_ peerConnection: RTCPeerConnection,
                      didChange newState: RTCIceConnectionState) {
    RTCLogEx(.verbose, "ICE state changed: \(newState)")
    DispatchQueue.main.async {
      self.delegate?.appClient(self, didChangeConnectionState: newState)
    }
  }

  func peerConnection(_ peerConnection: RTCPeerConnection,
                      didChange newState: RTCIceGatheringState) {
    RTCLogEx(.verbose, "ICE gathering state changed: \(newState)")
  }

  func peerConnection(_ peerConnection: RTCPeerConnection,
                      didGenerate candidate: RTCIceCandidate) {
    DispatchQueue.main.async {
      let message = ARDICECandidateMessage(candidate: candidate)
      self.sendSignalingMessage(message)
    }
  }

  func peerConnection(_ peerConnection: RTCPeerConnection,
                      didRemove candidates: [RTCIceCandidate]) {
    DispatchQueue.main.async {
      let message = ARDICECandidateRemovalMessage(removedCandidates: candidates)
      self.sendSignalingMessage(message)
    }
  }

  func peerConnection(_ peerConnection: RTCPeerConnection,
                      didOpen dataChannel: RTCDataChannel) {

  }
} // RTCPeerConnectionDelegate

// MARK: - RTCSessionDescriptionDelegate
// Callbacks for this delegate occur on non-main thread and need to be dispatched
// back to the main queue as needed.

// NOTE: the RTCSessionDescriptionDelegate seems to have disappeared (?) so
// I've implemented these functions anyway, even though there's no actual protocol
// associated with it (that I can find)

extension ARDAppClient {
  func peerConnection(_ peerConnection: RTCPeerConnection,
                      didCreate sessionDescription: RTCSessionDescription,
                      error: Error?) {
    DispatchQueue.main.async {
      if let err = error {
        RTCLogEx(.error, "Failed to create session description. Error: \(err)")
        self.disconnect()

        let userInfo = [
          NSLocalizedDescriptionKey: "Failed to create session description"
        ]

        let sdpError = NSError(domain: ARDAppClient.kErrorDomain,
            code: kClientError.createSDP.rawValue,
            userInfo: userInfo)

        self.delegate?.appClient(self, didError: sdpError)
        return
      } // if there was an error

      // prefer H264 if available
      let sdpPreferringH264 = ARDSDPUtils.makeDescriptionFor(
          description: sessionDescription,
          preferringVideoCodec: "H264")
      self._peerConnection?.setLocalDescription(sdpPreferringH264) {
          [weak self] error in

        if let strongSelf = self, let peerConnection = strongSelf._peerConnection {
          strongSelf.peerConnection(peerConnection,
              didSetSessionDescriptionWithError: error)
        }
      }

      let message = ARDSessionDescriptionMessage(description: sdpPreferringH264)
      self.sendSignalingMessage(message)
    } // async on main queue
  }  // (_:didCreate:error:)

  func peerConnection(_ peerConnection: RTCPeerConnection,
                      didSetSessionDescriptionWithError error: Error?) {
    DispatchQueue.main.async {
      if let err = error {
        RTCLogEx(.error, "Failed to set session description. Error: \(err)")
        self.disconnect()

        let userInfo = [
          NSLocalizedDescriptionKey: "Failed to set session description"
        ]
        let sdpError = NSError(domain: ARDAppClient.kErrorDomain,
            code: kClientError.setSDP.rawValue,
            userInfo: userInfo)
        self.delegate?.appClient(self, didError: sdpError)
        return
      } // error

      if !self.isInitiator && self._peerConnection?.localDescription == nil {
        let constraints = self.defaultAnswerConstraints
        self._peerConnection?.answer(for: constraints) {
            [weak self] sessionDescription, error in
          if let strongSelf = self,
              let connection = strongSelf._peerConnection,
              let description = sessionDescription {
            strongSelf.peerConnection(connection,
                didCreate: description, error: error)
          }
        }
      } // if !isInitiator and peerConnection.localDescription is empty
    }
  }
}
