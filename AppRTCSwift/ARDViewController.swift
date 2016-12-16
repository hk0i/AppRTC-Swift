//
//  ARDViewController.swift
//  AppRTCSwift
//
//  Created by Gregory McQuillan on 12/14/16.
//  Copyright © 2016 One Big Function. All rights reserved.
//

import UIKit
import WebRTC
import AVFoundation

//I might not use this image - GM
let barButtonImageString = "ic_settings_black_24dp.png"

class ARDMainViewController: UIViewController {

  internal var _mainView: ARDMainView?
  internal var _audioPlayer: AVAudioPlayer?
  internal var _useManualAudio: Bool?

  override func loadView() {
    self.title = "Swift AppRTC Mobile"
    self._mainView = ARDMainView(frame: CGRect.zero)
    self.view = self._mainView
    self.addSettingsBarButton()
    
//    var webRtcConfig = RTCAudioSessionConfiguration.webRTCConfiguration
//    webRtcConfig.categoryOptions = webRtcConfig.categoryOptions |
//        AVAudioSessionCategoryOptions.defaultToSpeaker
//    RTCAudioSessionConfiguration.setWebRTCConfiguration(webRtcConfig)

//    let session = RTCAudioSession.sharedInstance
//    session.addDelegate(self)

//    self.configureAudioSession()
    self.setUpAudioPlayer()

  }

  func addSettingsBarButton() {
    let settingsButton = UIBarButtonItem(title: "Settings", style:
        .plain, target: self, action: #selector(showSettings))
    self.navigationItem.rightBarButtonItem = settingsButton
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: Private

  func showSettings(sender AnyObject) {
    let settingsController = ARDSettingsViewController(style: .plain,
        mediaConstraintsModel: ARDMediaConstraintsModel())
    let navigationController = UINavigationController(rootViewController:
    settingsController)
    self.presentAsModal(viewController: settingsController)
  }

  func presentAsModal(viewController: UIViewController) {
    self.present(viewController, animated: false)
  }

  /*
  func configureAudioSession() {
    var configuration = RTCAudioSessionConfiguration()
    configuration.category = AVAudioSessionCategoryAmbient
    configuration.categoryOptions = AVAudioSessionCategoryOptions.duckOthers
    configuration.mode = AVAudioSessionModeDefault

    let session = RTCAudioSession.sharedInstance
    session.lockForConfiguration()
    var hasSucceeded = false
    let error: Error?
    if session.isActive {
      hasSucceeded = session.setConfiguration(configuration, error: error)
    }
    else {
      hasSucceeded = session.setConfiguration(configuration, active: true,
          error: error)
    }

    if !hasSucceeded {
      RTCLogError(String(format: "Error setting configuration: %@", error
          .localizedDescription))
    }
    session.unlockForConfiguration

  }
  */

  func setUpAudioPlayer() {
    let audioFilePath = Bundle.main.path(forResource: "mozart", ofType: "mp3")
    let audioFileUrl = URL(string: audioFilePath!)
    do {
      try self._audioPlayer = AVAudioPlayer(contentsOf: audioFileUrl!)
      
      self._audioPlayer!.numberOfLoops = -1
      self._audioPlayer!.volume = 1.0
      self._audioPlayer!.prepareToPlay()
    }
    catch {
      RTCLogEx(.error, "could not init audio player")
    }
  }

  func restartAudioPlayerIfNeeded() {
    if self._mainView!.isAudioLoopPlaying! && self.presentedViewController == nil {
      RTCLogEx(.warning, "Starting audio loop due to WebRTC end")
//      self.configureAudioSession()
      self._audioPlayer?.play()
    }
  }

  func showAlert(message: String) {
    let alertView = UIAlertView(title: "",
        message: message,
        delegate: nil,
        cancelButtonTitle: "OK")

    alertView.show()
  }

} // UIViewController

// MARK: ARDMainViewDelegate

extension ARDMainViewController : ARDMainViewDelegate {
  func mainView(_ mainView: ARDMainView, didInputRoom room: String,
                isLoopback: Bool, isAudioOnly: Bool, shouldMakeAecDump: Bool,
                shouldUseLevelControl: Bool, useManualAudio: Bool) {
    if !room.isEmpty {
      self.showAlert(message: "Missing room name.")
      return
    }

    let whitespaceSet = NSCharacterSet.whitespaces
    let trimmedRoom = room.trimmingCharacters(in: whitespaceSet)

    var error: Error?
    let options = NSRegularExpression.Options.caseInsensitive
    do {
      let regex = try NSRegularExpression(pattern: "\\w+", options: options)
      
      let matchRange = regex.rangeOfFirstMatch(in: trimmedRoom, options:
        NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(location: 0, length: trimmedRoom.characters.count))
      if matchRange.location == NSNotFound
        || matchRange.length != trimmedRoom.characters.count {
        self.showAlert(message: "Invalid room name")
        return
      }
      
      //    let session = RTCAudioSession.sharedInstance
      //    session.useManualAudio = useManualAudio
      //    session.isAudioEnabled = false
      
      let videoCallViewController: UIViewController = ARDVideoCallViewController(room:
        trimmedRoom,
                                                                                 isLoopback: isLoopback,
                                                                                 isAudioOnly: isAudioOnly,
                                                                                 shouldMakeAecDump: shouldMakeAecDump,
                                                                                 shouldUseLevelControl: shouldUseLevelControl,
                                                                                 delegate: self)
      
      videoCallViewController.modalTransitionStyle = .crossDissolve
      self.present(videoCallViewController, animated: true)
    }
    catch {
      self.showAlert(message: error.localizedDescription)
      return
    }

  }

  func mainViewDidToggleAudioLoop(mainView: ARDMainView) {
    if mainView.isAudioLoopPlaying! {
      self._audioPlayer?.stop()
    }
    else {
      self._audioPlayer?.play()
    }

    mainView.isAudioLoopPlaying = self._audioPlayer?.isPlaying
  }

} // ARDMainViewDelegate

extension ARDMainViewController : ARDVideoCallViewControllerDelegate {

  func viewControllerDidFinish(viewController: ARDVideoCallViewController) {
    if !viewController.isBeingDismissed {
      RTCLogEx(.info, "dismissing vc")
      self.dismiss(animated: true) {
        self.restartAudioPlayerIfNeeded()
      }
    }

//    let session = RTCAudioSession.sharedInstance
//    session.isAudioEnabled = false
  }
}

/*
extension ARDMainViewController : RTCAudioSessionDelegate {
  func audioSessionDidStartPlayOrRecord(session: RTCAudioSession) {
    RTCDispatcher.dispatchAsync(on: .typeMain) {
      if self._mainView.isAudioLoopPlaying {
        RTCLog("stopping audio loop due to WebRTC start.")
        self._audioPlayer.stop()
      }

      RTCLog("Setting isAudioEnabled to true")
      session.isAudioEnabled = true
    }
  }

  func audioSessionDidStopPlayOrRecord(session: RTCAudioSession) {
    RTCDispatcher.dispatchAsync(on: .typeMain) {
      RTCLog("audioSessionDidStopPlayOrRecord")
      self.restartAudioPlayerIfNeeded()
    }
  }
}
*/
