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

  private var _localVideoTrack: RTCVideoTrack?
  private var _remoteVideoTrack: RTCVideoTrack?
  private var _videoCallView: ARDVideoCallView?
  fileprivate var _portOverride: AVAudioSessionPortOverride?

  private var _client = ARDAppClient?

  init(room: String,
       isLoopback: Bool,
       isAudioOnly: Bool,
       shouldMakeAecDump: Bool,
       shouldUseLevelControl: Bool,
       delegate: ARDVideoCallViewControllerDelegate) {

    self.delegate = delegate
    self._client = ARDAppClient(delegate: self)
    var mediaConstraintsModel = ARDMediaConstraintsModel()
    var cameraConstraints = RTCMediaConstraints(mandatoryConstraints: nil,
        optionalConstraints: mediaConstraintsModel
            .currentMediaConstraintFromStoreAsRTCDictionary())
    self._client.setCameraConstraints(cameraConstraints)
    self._client.connectToRoom(withId: room,
        isLoopback: isLoopback,
        isAudioOnly: isAudioOnly,
        shouldMakeAecDump: shouldMakeAecDump,
        shouldUseLevelControl: shouldUseLevelControl)

  }

  override func loadView() {
    self._videoCallView = ARDVideoCallView(frame: CGRect.zero)
    self._videoCallView.delegate = self
    self._videoCallView.statusLabel.text
        = self.statusText(forState: RTCIceConnectionState.new)
    self.view = self._videoCallView
  }

  required init(coder: NSCoder) {
    assertionFailure("Storyboard not supported")
  }

  // MARK: private

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

    self._videoCallView.localVideoView.captureSession = source.captureSession
  }

  func setRemoteVideoTrack(_ remoteVideoTrack: RTCVideoTrack) {
    if self._remoteVideoTrack == remoteVideoTrack {
      return
    }

    self._remoteVideoTrack.remove(_videoCallView.remoteVidoeView)
    self._remoteVideoTrack = nil
    self._videoCallView.remoteVideoView.render(frame: nil)
    self._remoteVideoTrack = remoteVideoTrack
    self._remoteVideoTrack.add(_videoCallView.remoteVideoView)
  }

  func hangUp() {
    self._remoteVideoTrack = nil
    self._localVideoTrack = nil
    self._client.disconnect()
    self.delegate.viewControllerDidFinish(viewController: self)
  }

  func switchCamera() {
    var source = self._localVideoTrack.source
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
        delegate: nil, cancelButtonTitle: "OK", otherButtonTitles: nil)

    alertView.show()
  }

}

// MARK: ARDAppClientDelegate

extension ARDVideoCallViewController: ARDAppClientDelegate {
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

  func appClient(_ client: ARDClient,
                 didReceiveLocalVideoTrack localVideoTrack: RTCVideoTrack) {
    self._localVideoTrack = localVideoTrack
  }

  func appClient(_ client: ARDClient,
                 didGetStats stats: [Any]) {
    self._videoCallView.statsView.stats = stats
  }

  func appClient(_ client: ARDClient,
                 didError error: Error) {
    let message = error.localizedDescription
    self.showAlert(withMessage: message)
    self.hangUp()
  }
}

// MARK: ARDVideoCallViewDelegate

extension ARDVideoCallViewController: ARDVideoCallViewDelegate {
  func videoCallViewDidHangUp(view: ARDVideoCallView) {
    self.switchCamera()
  }

  func videoCallViewDidSwitchCamera(view: ARDVideoCallView) {
    self.switchCamera()
  }

  func videoCallViewDidChangeRoute(view: ARDVideoCallView) {
    var override = AVAudioSessionPortOverride.none
    if self._portOverride == .none {
      override = .speaker
    }

    print("WARNING: Removed audio session code for didChangeRoute")

    /*
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
    self._client.shouldGetStats = true
    self._videoCallView.statsView.hidden = false
  }
}
