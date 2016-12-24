//
// Created by Gregory McQuillan on 12/23/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import WebRTC
import Foundation

class ARDSDPUtils {
  /**
   * Updates the original SDP description to instead prefer the specified
   * video codec. We do this by placing the specified codec at the beginning of
   * the codec list if it already exists in the sdp.
   *
   * NOTE: renamed this because it seems more or less like a factory method.
   */
  static func makeDescriptionFor(description: RTCSessionDescription,
                             preferringVideoCodec codec: String)
          -> RTCSessionDescription {
    //Supposedly this was copied from PeerConnectionClient.java
    let lineSeparator = "\n"
    var lines = description.sdp.components(separatedBy: lineSeparator)
    // note: m is not an abbreviation, it refers to lines that begin m=...
    var mLineIndex = -1
    var codecRtpMap: String?
    // a=rtpmap:<payload type> <encoding name>/<clock rate>
    // [/<encoding parameters>]
    let pattern = "^a=rtpmap:(\\d+) \(codec)(/\\d+)+[\r]?$"

    for i in (0 ..< lines.count) where mLineIndex == -1 || codecRtpMap == nil {
      let line = lines[i]
      if line.hasPrefix("m=video") {
        mLineIndex = i
        continue
      }

      // note: original code uses NSRegularExpression which brought me into
      //       a world of pain, so I changed it to use range(of:options:)
      if let codecMatches = line.range(of: pattern, options: .regularExpression) {
        codecRtpMap = line.substring(with: codecMatches)
        continue
      }
    }

    if mLineIndex == -1 {
      RTCLogEx(.warning, "No m=video line, so can't prefer \(codec)")
      return description
    }

    // note: uw stands for unwrapped
    guard let uwCodecRtpMap = codecRtpMap else {
      RTCLogEx(.warning, "No rtpmap for \(codec)")
      return description
    }

    let mLineSeparator = " "
    let origMLineParts
        = lines[mLineIndex].components(separatedBy: mLineSeparator)
    if origMLineParts.count > 3 {
      var newMLineParts = [String](repeating: "", count: origMLineParts.count)
      // format is: m=<media> <port> <proto> <fmt>

      // note: var++ is removed in Swift 3, so i had to make due
      var origPartIndex = 1

      newMLineParts.append(origMLineParts[origPartIndex])
      origPartIndex += 1

      newMLineParts.append(origMLineParts[origPartIndex])
      origPartIndex += 1

      newMLineParts.append(origMLineParts[origPartIndex])
      origPartIndex += 1

      newMLineParts.append(uwCodecRtpMap)

      while origPartIndex < origMLineParts.count {
        origPartIndex += 1
        if uwCodecRtpMap != origMLineParts[origPartIndex] {
          newMLineParts.append(origMLineParts[origPartIndex])
        }
      }
    }
    else {
      // if origMLineParts.count is <= 3
      RTCLogEx(.warning, "Wrong SDP media description format: "
          + "\(lines[mLineIndex])")
    }

    let mangledSdpString = lines.joined(separator: lineSeparator)
    return RTCSessionDescription(type: description.type, sdp: mangledSdpString)
  }
}
