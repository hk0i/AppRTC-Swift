//
// Created by Gregory McQuillan on 12/16/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import Foundation

class ARDMediaConstraintsSettingsStore {

  let kUserDefaultsMediaConstraintsKey
      = "rtc_video_resolution_media_constraints_key"

  /**
   * Light-weight persistent store for media constraints user settings.
   * Persists between application launches and application updates
   */
  func videoResolutionConstraintsSetting() -> String? {
    if let videoRes =  UserDefaults.standard.value(
        forKey: kUserDefaultsMediaConstraintsKey) as? String {
      return videoRes
    }

    return nil
  }

  /**
   * Stores the provided value as a video resolution media constraint.
   *
   * - parameter value: the string to be stored
   */
  func setVideoResolutionConstraintsSetting(_ constraintsString: String) {
    UserDefaults.standard.set(constraintsString,
        forKey: kUserDefaultsMediaConstraintsKey)
  }
}
