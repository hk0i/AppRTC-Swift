//
// Created by Gregory McQuillan on 12/16/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import WebRTC
import UIKit
import Foundation
import AVFoundation

protocol ARDVideoCallViewControllerDelegate {
  func viewControllerDidFinish(viewController: ARDVideoCallViewController)
}

class ARDVideoCallViewController: UIViewController {

  var delegate: ARDVideoCallViewControllerDelegate?

  fileprivate var _localVideoTrack: RTCVideoTrack?
  fileprivate var _remoteVideoTrack: RTCVideoTrack?
  fileprivate var _videoCallView: ARDVideoCallView?
  fileprivate var _portOverride: AVAudioSessionPortOverride?

  fileprivate var _client: ARDAppClient?

  init(room: String,
       isLoopback: Bool,
       isAudioOnly: Bool,
       shouldMakeAecDump: Bool,
       shouldUseLevelControl: Bool,
       delegate: ARDVideoCallViewControllerDelegate) {

    self.delegate = delegate
    self._client = ARDAppClient(delegate: self)
    let mediaConstraintsModel = ARDMediaConstraintsModel()
    let cameraConstraints = RTCMediaConstraints(mandatoryConstraints: nil,
        optionalConstraints: mediaConstraintsModel
            .currentMediaConstraintFromStoreAsRTCDictionary())
    self._client?.cameraConstraints = cameraConstraints
    self._client?.connectToRoom(roomId: room,
        isLoopback: isLoopback,
        isAudioOnly: isAudioOnly,
        shouldMakeAecDump: shouldMakeAecDump,
        shouldUseLevelControl: shouldUseLevelControl)

  }

  override func loadView() {
    self._videoCallView = ARDVideoCallView(frame: CGRect.zero)
    self._videoCallView!.delegate = self
    self._videoCallView!.statusLabel!.text
        = self.statusText(forState: RTCIceConnectionState.new)
    self.view = self._videoCallView
  }

  required init(coder: NSCoder) {
    assertionFailure("Storyboard not supported")
  }

  // MARK: - Private

  func setLocalVideoTrack(_ localVideoTrack: RTCVideoTrack) {
    if self._localVideoTrack == localVideoTrack {
      return
    }

    self._localVideoTrack = nil
    self._localVideoTrack = localVideoTrack

    var source: RTCAVFoundationVideoSource?
    if let localSource = localVideoTrack.source as? RTCAVFoundationVideoSource {
      source = localSource
    }

    self._videoCallView!.localVideoView!.captureSession = source!.captureSession
  }

  func setRemoteVideoTrack(_ remoteVideoTrack: RTCVideoTrack) {
    if self._remoteVideoTrack == remoteVideoTrack {
      return
    }

    self._remoteVideoTrack!.remove(_videoCallView!.remoteVideoView!)
    self._remoteVideoTrack = nil
    self._videoCallView!.remoteVideoView!.renderFrame(nil)
    self._remoteVideoTrack = remoteVideoTrack
    self._remoteVideoTrack!.add(_videoCallView!.remoteVideoView!)
  }

  func hangUp() {
    self._remoteVideoTrack = nil
    self._localVideoTrack = nil
    self._client?.disconnect()
    self.delegate!.viewControllerDidFinish(viewController: self)
  }

  func switchCamera() {
    let source = self._localVideoTrack?.source
    if let avSource = source as? RTCAVFoundationVideoSource {
      avSource.useBackCamera = !avSource.useBackCamera
    }
  }

  func statusText(forState state: RTCIceConnectionState) -> String? {
    switch (state) {
      case .new: fallthrough
      case .checking:
        print("Connecting ...")

      default:
        return nil
    }
  }

  func showAlert(withMessage message: String) {
    let alertView = UIAlertView(title: nil, message: message,
                                delegate: nil, cancelButtonTitle: "OK")

    alertView.show()
  }

}

// MARK: - ARDAppClientDelegate

extension ARDVideoCallViewController: ARDAppClientDelegate {
  internal func appClient(_ client: ARDAppClient,
                          didChangeConnectionState state: RTCIceConnectionState) {
//    RTCLogEx(.info, String(format: "ICE state changed: %d", Int(state)))
    DispatchQueue.main.async { [weak self] in
      if let strongSelf = self {
        strongSelf._videoCallView?.statusLabel?.text
          = strongSelf.statusText(forState: state)
      }
    }
  }

  func appClient(_ client: ARDAppClient,
                 didChangeState state: ARDAppClientState) {
    switch (state) {
      case .connected:
        print("Client connected.")

      case .connecting:
        print("Client connecting...")

      case .disconnected:
        print("Client disconnected.")
        self.hangUp()

      default:
        print("Shrug?")
    }
  }

  func appClient(_ client: ARDAppClient,
                 didReceiveLocalVideoTrack localVideoTrack: RTCVideoTrack) {
    self._localVideoTrack = localVideoTrack
  }
  
  func appClient(_ client: ARDAppClient,
                 didReceiveRemoteVideoTrack remoteVideoTrack: RTCVideoTrack) {
    self._remoteVideoTrack = remoteVideoTrack
    self._videoCallView?.statusLabel?.isHidden = true
  }

  func appClient(_ client: ARDAppClient,
                 didGetStats stats: [RTCLegacyStatsReport]) {
    self._videoCallView?.statsView?.stats = stats
  }

  func appClient(_ client: ARDAppClient,
                 didError error: Error) {
    let message = error.localizedDescription
    self.showAlert(withMessage: message)
    self.hangUp()
  }
}

// MARK: - ARDVideoCallViewDelegate

extension ARDVideoCallViewController: ARDVideoCallViewDelegate {
  func videoCallViewDidHangUp(_ view: ARDVideoCallView) {
    self.switchCamera()
  }

  func videoCallViewDidSwitchCamera(_ view: ARDVideoCallView) {
    self.switchCamera()
  }

  func videoCallViewDidChangeRoute(_ view: ARDVideoCallView) {
    print("WARNING: Removed audio session code for didChangeRoute")

    /*
    var override = AVAudioSessionPortOverride.none
    if self._portOverride == .none {
      override = .speaker
    }
    
    RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
    var session = RTCAudioSession.sharedInstance()
    session.lockForConfiguration()
    var error: Error?
    if session.overrideOutputAudioPort(override, error: error) {
      self._portOverride = override
    }
    else {
      print("Error overriding output port: %@", error.localizedDescription)
    }
    session.unlockForConfiguration()
    } //RTCDispatcher async block
    */
  }

  func videoCallViewDidEnableStats(_ view: ARDVideoCallView) {
    self._client?.shouldGetStats = true
    self._videoCallView?.statsView?.isHidden = false
  }
}
