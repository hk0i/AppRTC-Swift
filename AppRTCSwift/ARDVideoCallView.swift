//
// Created by Gregory McQuillan on 12/19/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import UIKit
import WebRTC

protocol ARDVideoCallViewDelegate: NSObjectProtocol {
  /// Called when the camera switch button is pressed.
  func videoCallViewDidSwitchCamera(_ view: ARDVideoCallView)

  /// Called when the route change button is pressed
  func videoCallViewDidChangeRoute(_ view: ARDVideoCallView)

  /// Called when the hang up button is pressed.
  func videoCallViewDidHangUp(_ view: ARDVideoCallView)

  /// Called when stats are enabled by triple tapping.
  func videoCallViewDidEnableStats(_ view: ARDVideoCallView)
}

class ARDVideoCallView: UIView {

  // MARK: from header file

  var statusLabel: UILabel?
  var localVideoView: RTCCameraPreviewView?
  var remoteVideoView: RTCEAGLVideoView?
  var statsView: ARDStatsView?
  var delegate: ARDVideoCallViewDelegate?

  // MARK: from implementation

  private var _routeChangeButton: UIButton?
  private var _cameraSwitchButton: UIButton?
  private var _hangUpButton: UIButton?
  fileprivate var _remoteVideoSize: CGSize?
  private var _useRearCamera: Bool?

  fileprivate static let kButtonPadding: CGFloat = 16
  fileprivate static let kButtonSize: CGFloat = 48
  fileprivate static let kLocalVideoViewSize: CGFloat = 120
  fileprivate static let kLocalVideoViewPadding: CGFloat = 8
  fileprivate static let kStatusBarHeight: CGFloat = 20

  override init(frame: CGRect) {
    self.remoteVideoView = RTCEAGLVideoView(frame: .zero)
    self.remoteVideoView!.delegate = self
    self.addSubview(self.remoteVideoView!)

    self.localVideoView = RTCCameraPreviewView(frame: .zero)
    self.addSubview(self.localVideoView!)

    self.statsView = ARDStatsView(frame: .zero)
    self.statsView!.isHidden = true
    self.addSubview(self.statsView!)

    self._routeChangeButton = UIButton(type: .custom)
    // omitted: button image
    self._routeChangeButton!.addTarget(self, action: #selector(onRouteChange),
        for: .touchUpInside)
    self.setUpButton(self._routeChangeButton, color: .white)
    self.addSubview(self._routeChangeButton!)

    self._hangUpButton = UIButton(type: .custom)
    self.setUpButton(self._hangUpButton, color: .red)
    // omitted: button image
    self._hangUpButton!.addTarget(self, action: #selector(onHangUp),
        for: .touchUpInside)

    self.statusLabel = UILabel(frame: .zero)
    // omitted: Roboto font change
    self.statusLabel!.textColor = .white
    self.addSubview(self.statusLabel!)

    let tapRecognizer = UITapGestureRecognizer(target: self,
        action: #selector(didTripleTap))
    tapRecognizer.numberOfTapsRequired = 3
    self.addGestureRecognizer(tapRecognizer)
  } //init(frame:)

  /// added required initializer for swift
  required init(coder: NSCoder) {
    fatalError("Storyboard not supported")
  }

  override func layoutSubviews() {
    let bounds = self.bounds
    if let remoteVideoSize = self._remoteVideoSize {
      if remoteVideoSize.width > 0 && remoteVideoSize.height > 0 {
        // aspect fill remote video into bounds
        var remoteVideoFrame = AVMakeRect(aspectRatio: remoteVideoSize,
            insideRect: bounds)
        var scale: CGFloat = 1;
        if remoteVideoFrame.size.width > remoteVideoFrame.size.height {
          // scale by height
          scale = bounds.size.height / remoteVideoFrame.size.height
        } else {
          // scale by width
          scale = bounds.size.width / remoteVideoFrame.size.width
        }
        remoteVideoFrame.size.height *= scale
        remoteVideoFrame.size.width *= scale

        self.remoteVideoView!.frame = remoteVideoFrame
        self.remoteVideoView!.center = CGPoint(x: bounds.midX, y: bounds.midY)
      }
      else {
        self.remoteVideoView!.frame = bounds
      } // if remote width/height > 0
    } // unwrap remoteVideoSize

    // aspect fill local video view into a square box
    var localVideoFrame = CGRect(x: 0, y: 0,
        width: ARDVideoCallView.kLocalVideoViewSize,
        height: ARDVideoCallView.kLocalVideoViewSize)

    // place the view in the bottom right
    localVideoFrame.origin.x = bounds.maxX
        - localVideoFrame.size.width - ARDVideoCallView.kLocalVideoViewPadding
    localVideoFrame.origin.y = bounds.maxY
        - localVideoFrame.size.height - ARDVideoCallView.kLocalVideoViewPadding
    self.localVideoView!.frame = localVideoFrame

    // place stats on the top
    let statsSize = self.statsView!.sizeThatFits(bounds.size)
    self.statsView!.frame = CGRect(x: bounds.minX,
        y: bounds.minY + ARDVideoCallView.kStatusBarHeight,
        width: statsSize.width, height: statsSize.height)

    // place the hang up button on the bottom left
    self._hangUpButton!.frame = CGRect(
        x: bounds.minX + ARDVideoCallView.kButtonPadding,
        y: bounds.maxY - ARDVideoCallView.kButtonPadding - ARDVideoCallView.kButtonSize,
        width: ARDVideoCallView.kButtonSize,
        height: ARDVideoCallView.kButtonSize)

    // place camera switch button to the right of the hang up button
    var cameraSwitchFrame = self._hangUpButton!.frame
    cameraSwitchFrame.origin.x
        = cameraSwitchFrame.maxX + ARDVideoCallView.kButtonPadding
    self._cameraSwitchButton!.frame = cameraSwitchFrame

    // place route button to the right of camera button
    var routeChangeFrame = self._cameraSwitchButton!.frame
    routeChangeFrame.origin.x
        = routeChangeFrame.maxX + ARDVideoCallView.kButtonPadding
    self._routeChangeButton!.frame = routeChangeFrame

    self.statusLabel!.sizeToFit()
    self.statusLabel!.center = CGPoint(x: bounds.midX, y: bounds.midY)

  } // layoutSubviews

  /// Not in the original code, I added this for brevity - GM
  private func setUpButton(_ button: UIButton?, color: UIColor?) {
    if let btn = button {
      let color = color ?? UIColor.white

      btn.backgroundColor = color
      btn.layer.cornerRadius = ARDVideoCallView.kButtonSize / 2;
      btn.layer.masksToBounds = true
    }
  }

  // MARK: Private

  func onCameraSwitch(sender: AnyObject?) {
    self.delegate?.videoCallViewDidSwitchCamera(self)
  }

  func onRouteChange(sender: AnyObject?) {
    self.delegate?.videoCallViewDidChangeRoute(self)
  }

  func onHangUp(sender: AnyObject?) {
    self.delegate?.videoCallViewDidHangUp(self)
  }

  func didTripleTap(recognizer: UITapGestureRecognizer?) {
    self.delegate?.videoCallViewDidEnableStats(self)
  }

}

// MARK: RTCEAGLVideoViewDelegate

extension ARDVideoCallView: RTCEAGLVideoViewDelegate {
  func videoView(_ videoView: RTCEAGLVideoView, didChangeVideoSize size: CGSize) {
    if (videoView == self.remoteVideoView) {
      self._remoteVideoSize = size
    }

    self.setNeedsLayout()
  }
}
