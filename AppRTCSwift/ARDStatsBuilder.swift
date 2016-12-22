//
// Created by Gregory McQuillan on 12/21/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import WebRTC
import Foundation

/**
 * Class used to accumulate stats information into a single displayable string
 * TODO: implement this class
 *
 * Note: I haven't implemented this yet
 */
class ARDStatsBuilder {
  /**
   * String that represents the accumulated stats reports passed into this
   * class.
   */
  var statsString: String {
    get {
      return "Not implemented"
    }
  }

  /**
   * Parses the information in the stats report into an appropriate internal
   * format used to generate the stats string
   */
  func parse(statsReport report: RTCLegacyStatsReport) {

  }

}
