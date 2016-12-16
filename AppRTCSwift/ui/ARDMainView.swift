//
// Created by Gregory McQuillan on 12/14/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import UIKit
import Foundation

let kRoomTextFieldHeight: CGFloat = 40.0
let kRoomTextFieldMargin: CGFloat = 8.0
let kCallControlMargin: CGFloat = 8.0

//TODO: rename all private variables to use _ prefix to match original code
// a little better.

private class ARDRoomTextField: UIView {

  private var roomTextView: UITextField?

  var roomText: String {
    get {
      return roomTextView?.text ?? ""
    }
  }

  /**
   * note: not in the original because ObjC implicitly inherits this,
   * however, since the original code does not support storyboard I
   * will throw an error here
   * **see**: [StackOverflow](http://stackoverflow
   .com/questions/25126295/class-does-not-implement-its-superclasss-required-members)
   */
  required init(coder: NSCoder) {
    fatalError("NSCoding not supported")
  }

  override init(frame: CGRect) {
    super.init(frame: frame)

    self.roomTextView = UITextField(frame: CGRect.zero)

    if let roomTextView = self.roomTextView {
      roomTextView.borderStyle = .none
      //omitted: setting font to roboto. I don't want to copy the font, etc - GM
      roomTextView.placeholder = "Room name"
      roomTextView.autocorrectionType = .no
      roomTextView.autocapitalizationType = .none
      roomTextView.clearButtonMode = .always
      roomTextView.delegate = self
      self.addSubview(self.roomTextView!)
    } else {
      //this is my own doing
      assertionFailure("sorry no text view available")
    }

    self.layer.borderWidth = 1
    self.layer.borderColor = UIColor.black.cgColor
    self.layer.cornerRadius = 2

  } // initWithFrame

  override func layoutSubviews() {
    self.roomTextView!.frame =
      CGRect(x: kRoomTextFieldMargin, y: 0,
             width: self.bounds.width - kRoomTextFieldMargin,
             height: kRoomTextFieldHeight)
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    var newSize = size
    newSize.height = kRoomTextFieldHeight
    return size
  }
} // ARDRoomTextField

// MARK: UITextViewDelegate
extension ARDRoomTextField : UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
} // ARDRoomTextField : UITextFieldDelegate

// MARK: ARDMainView Delegate

protocol ARDMainViewDelegate : NSObjectProtocol {
  func mainView(_: ARDMainView, didInputRoom: String, isLoopback: Bool,
                isAudioOnly: Bool, shouldMakeAecDump: Bool,
                shouldUseLevelControl: Bool, useManualAudio: Bool)

  func mainViewDidToggleAudioLoop(mainView: ARDMainView)
}

// MARK: ARDMainView

/**
 * The main view of AppRTCMobile. It contains an input field for
 * entering an AppRTC room name to connect to.
 */
class ARDMainView: UIView {
  var delegate: ARDMainViewDelegate?
  var isAudioLoopPlaying: Bool?

  private var roomTextField: ARDRoomTextField?
  private var callOptionsLabel: UILabel?

  // call option switch + label sets
  private var audioOnlySwitch: UISwitch?
  private var audioOnlyLabel: UILabel?

  private var aecDumpSwitch: UISwitch?
  private var aecDumpLabel: UILabel?

  private var levelControlSwitch: UISwitch?
  private var levelControlLabel: UILabel?

  private var loopbackSwitch: UISwitch?
  private var loopbackLabel: UILabel?

  private var useManualAudioSwitch: UISwitch?
  private var useManualAudioLabel: UILabel?

  private var startCallButton: UIButton?
  private var audioLoopButton: UIButton?

  /**
   * note: not in the original because ObjC implicitly inherits this,
   * however, since the original code does not support storyboard I
   * will throw an error here
   * **see**: [StackOverflow](http://stackoverflow
   .com/questions/25126295/class-does-not-implement-its-superclasss-required-members)
   */
  required init(coder: NSCoder) {
    fatalError("NSCoding not supported")
  }

  override init(frame: CGRect) {
    super.init(frame: frame)

    self.roomTextField = ARDRoomTextField(frame: CGRect.zero)
    self.addSubview(self.roomTextField!)

    //omitted: control font
    let controlFontColor = UIColor(white: 0, alpha: 0.6)

    self.callOptionsLabel!.text = "Call Options"
    self.callOptionsLabel!.textColor = controlFontColor
    self.callOptionsLabel!.sizeToFit()
    self.addSubview(self.callOptionsLabel!)

    self.audioOnlySwitch = UISwitch(frame: CGRect.zero)
    self.audioOnlySwitch!.sizeToFit()
    self.addSubview(audioOnlySwitch!)

    self.audioOnlyLabel!.text = "Call Options"
    self.audioOnlyLabel!.textColor = controlFontColor
    self.audioOnlyLabel!.sizeToFit()
    self.addSubview(self.audioOnlyLabel!)

    self.loopbackSwitch = UISwitch(frame: CGRect.zero)
    self.loopbackSwitch!.sizeToFit()
    self.addSubview(loopbackSwitch!)

    self.loopbackLabel!.text = "Call Options"
    self.loopbackLabel!.textColor = controlFontColor
    self.loopbackLabel!.sizeToFit()
    self.addSubview(self.loopbackLabel!)

    self.aecDumpSwitch = UISwitch(frame: CGRect.zero)
    self.aecDumpSwitch!.sizeToFit()
    self.addSubview(aecDumpSwitch!)

    self.aecDumpLabel!.text = "Call Options"
    self.aecDumpLabel!.textColor = controlFontColor
    self.aecDumpLabel!.sizeToFit()
    self.addSubview(self.aecDumpLabel!)

    self.levelControlSwitch = UISwitch(frame: CGRect.zero)
    self.levelControlSwitch!.sizeToFit()
    self.addSubview(levelControlSwitch!)

    self.levelControlLabel!.text = "Call Options"
    self.levelControlLabel!.textColor = controlFontColor
    self.levelControlLabel!.sizeToFit()
    self.addSubview(self.levelControlLabel!)

    self.useManualAudioSwitch = UISwitch(frame: CGRect.zero)
    self.useManualAudioSwitch!.sizeToFit()
    self.addSubview(useManualAudioSwitch!)

    self.useManualAudioLabel!.text = "Call Options"
    self.useManualAudioLabel!.textColor = controlFontColor
    self.useManualAudioLabel!.sizeToFit()
    self.addSubview(self.useManualAudioLabel!)

    self.startCallButton = UIButton(type: .system)
    self.startCallButton!.setTitle("Start Call", for: .normal)
    self.startCallButton!.sizeToFit()
    self.startCallButton!.addTarget(self, action:
        #selector(onStartCall), for: .touchUpInside)
    self.addSubview(startCallButton!)

    //used to test what happens to sounds when calls are in progress
    self.audioLoopButton = UIButton(type: .system)
    self.updateAudioLoopButton()
    self.audioLoopButton!.addTarget(self,
                                   action: #selector(onToggleAudioLoop), for: .touchUpInside)
    self.addSubview(self.audioLoopButton!)

    self.backgroundColor = UIColor.white

  }
  

  //omitted: setIsAudioLoopPlaying setter

  override func layoutSubviews() {
    let bounds = self.bounds
    let roomTextWidth = bounds.size.width - 2 * kRoomTextFieldMargin
    let roomTextHeight = self.roomTextField!.sizeThatFits(bounds.size).height

    self.roomTextField!.frame = CGRect(x: kRoomTextFieldMargin, y: kRoomTextFieldMargin,
        width: roomTextWidth, height: roomTextHeight)

    let callOptionsLabelTop = self.roomTextField!.frame.maxY + kCallControlMargin * 4
    self.callOptionsLabel!.frame = CGRect(x: kCallControlMargin, y: callOptionsLabelTop,
        width: self.callOptionsLabel!.frame.size.width,
        height: self.callOptionsLabel!.frame.size.height)

    let audioOnlyTop = self.callOptionsLabel!.frame.maxY + kCallControlMargin * 2
    let audioOnlyRect = CGRect(x: kCallControlMargin * 3, y: audioOnlyTop,
        width: self.audioOnlySwitch!.frame.size.width,
        height: self.audioOnlySwitch!.frame.size.height)
    self.audioOnlySwitch!.frame = audioOnlyRect
    let audioOnlyLabelCenterX = self.audioOnlyLabel!.frame.size.width / 2
    self.audioOnlyLabel!.center = CGPoint(x: audioOnlyLabelCenterX,y: audioOnlyRect.midY)

    let loopbackModeTop = self.audioOnlySwitch!.frame.maxY + kCallControlMargin
    let loopbackModeRect = CGRect(x: kCallControlMargin * 3, y: loopbackModeTop,
        width: self.loopbackSwitch!.frame.size.width,
        height: self.loopbackSwitch!.frame.size.height)
    self.loopbackSwitch!.frame = loopbackModeRect

    let loopbackModeLabelCenterX = loopbackModeRect.maxX
        + kCallControlMargin + self.loopbackLabel!.frame.size.width / 2
    loopbackLabel!.center = CGPoint(x: loopbackModeLabelCenterX, y: loopbackModeRect.midY)

    let aecDumpModeTop = self.loopbackSwitch!.frame.maxY + kCallControlMargin
    let aecDumpModeRect = CGRect(x: kCallControlMargin * 3, y: aecDumpModeTop,
        width: self.aecDumpSwitch!.frame.size.width,
        height: self.aecDumpSwitch!.frame.size.height)
    self.aecDumpSwitch!.frame = aecDumpModeRect
    let aecDumpModeLabelCenterX = aecDumpModeRect.maxX
        + kCallControlMargin + self.aecDumpLabel!.frame.size.width / 2
    self.aecDumpLabel!.center = CGPoint(x: aecDumpModeLabelCenterX, y: aecDumpModeRect.midY)

    let levelControlModeTop = self.aecDumpSwitch!.frame.maxY + kCallControlMargin
    let levelControlModeRect = CGRect(x: kCallControlMargin * 3,
        y: levelControlModeTop,
        width: self.levelControlSwitch!.frame.size.width,
        height: self.levelControlSwitch!.frame.size.height)
    self.levelControlSwitch!.frame = levelControlModeRect
    let levelControlModeLabelCenterX = levelControlModeRect.maxX
        + kCallControlMargin + self.levelControlLabel!.frame.size.width / 2
    self.levelControlLabel!.center = CGPoint(x: levelControlModeLabelCenterX,
        y: levelControlModeRect.midY)

    let useManualAudioTop = self.levelControlSwitch!.frame.maxY + kCallControlMargin
    let useManualAudioRect = CGRect(x: kCallControlMargin * 3, y: useManualAudioTop,
        width: self.useManualAudioSwitch!.frame.size.width,
        height: self.useManualAudioSwitch!.frame.size.height)
    self.useManualAudioSwitch!.frame = useManualAudioRect
    let useManualAudioLabelCenterX = useManualAudioRect.maxX
        + kCallControlMargin + self.useManualAudioLabel!.frame.size.width / 2
    self.useManualAudioLabel!.center = CGPoint(x: useManualAudioLabelCenterX,
                                              y: useManualAudioRect.midY)

    let audioLoopTop = useManualAudioRect.maxY + kCallControlMargin * 3
    self.audioLoopButton!.frame = CGRect(x: kCallControlMargin, y: audioLoopTop,
        width: self.audioLoopButton!.frame.size.width,
        height: self.audioLoopButton!.frame.size.height)

    let startCallTop = self.audioLoopButton!.frame.maxY + kCallControlMargin * 3
    startCallButton!.frame = CGRect(x: kCallControlMargin, y: startCallTop,
        width: self.startCallButton!.frame.size.width,
        height: self.startCallButton!.frame.size.height)
  } // layoutSubviews

  // MARK: Private

  func updateAudioLoopButton() {
    if self.isAudioLoopPlaying! {
      self.audioLoopButton!.setTitle("Stop sound", for: .normal)
      self.audioLoopButton!.sizeToFit()
    }
    else {
      self.audioLoopButton!.setTitle("Play sound", for: .normal)
      self.audioLoopButton!.sizeToFit()
    }
  }

  func onToggleAudioLoop(sender: AnyObject) {
    self.delegate?.mainViewDidToggleAudioLoop(mainView: self)
  }

  func onStartCall(sender: AnyObject) {
    var room = self.roomTextField!.roomText
    if room.isEmpty && self.loopbackSwitch!.isOn {
      room = NSUUID.init().uuidString
    }

    room = room.replacingOccurrences(of: "-", with: "")
    self.delegate?.mainView(self, didInputRoom: room,
        isLoopback: self.loopbackSwitch!.isOn,
        isAudioOnly: self.audioOnlySwitch!.isOn,
        shouldMakeAecDump: self.aecDumpSwitch!.isOn,
        shouldUseLevelControl: self.levelControlSwitch!.isOn,
        useManualAudio: self.useManualAudioSwitch!.isOn)
  }
}
