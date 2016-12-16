//
// Created by Gregory McQuillan on 12/15/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import Foundation
import WebRTC

let videoResolutionsStaticValues = [
    "640x480",
    "960x540",
    "1280x720"
]

/**
 * Model class for user defined media constraints.
 *
 * Currently used for streaming media constraints only.
 * In future audio media constraints support can be added as well.
 * Offers list of avaliable video resolutions that can construct streaming media constraint.
 * Exposes methods for reading and storing media constraints from persistent store.
 * Also translates current user defined media constraint into RTCMediaConstraints
 * dictionary.
 */
class ARDMediaConstraintsModel {

  private lazy var _settingsStore = ARDMediaConstraintsSettingsStore()

  /**
   * Returns an array of available capture resolutions
   *
   * The capture resolutions are represented as strings in the following format:
   * [width]x[height]
   */
  func availableVideoResolutionsMediaConstraints() -> [String] {
    return videoResolutionsStaticValues
  }

  /**
   * Returns current video resolution media constraint string.
   * If no constraint is in the store, default value of 640x480 is returned.
   * When defaulting to value, the default is saved in store for
   * consistency reasons.
   */
  func currentVideoResolutionConstraintFromStore() -> String {
    var constraint = self._settingsStore.videoResolutionConstraintsSetting()
    if constraint.isEmpty {
      constraint = self.defaultVideoResolutionConstraintsSetting(constraint)
      self._settingsStore.setVideoResolutionConstraintsSetting(constraint)
    }

    return constraint;
  }

  /**
   * Stores the provided video resolution media constraint string into the
   * store.
   *
   * If the provided constraint is no part of the available video resolutions
   * the store operation will not be executed and `false` will be returned.
   *
   * - parameter constraint: the string to be stored
   * - returns: `true` on success, `false` on failure.
   */
  func storeVideoResolutionConstraint(_ constraint: String) -> Bool {
    if (!self.availableVideoResolutionsMediaConstraints()
        .contains(constraint)) {
      return false
    }

    self._settingsStore.setVideoResolutionConstraintsSetting(constraint)
    return true
  }

  // MARK: - testable

  // omitted: lazy initializer for _settingsStore property moved to top using
  // swift lazy initializers

  /**
   * Returns the current selected width resolution from store.
   * Converted to a computed property from the objc implementation
   */
  var currentVideoResolutionWidthFromStore: String? {
    get {
      let mediaConstraintFromStore = self.currentVideoResolutionConstraintFromStore()

      return self.videoResolutionComponent(index: 0,
          inConstraintsString: mediaConstraintFromStore)
    }
  }

  /**
   * Returns the current selected height resolution from store.
   * Converted to a computed property from the objc implementation
   */
  var currentVideoResolutionHeightFromStore: String? {
    get {
      let mediaConstraintFromStore = self.currentVideoResolutionConstraintFromStore()

      return self.videoResolutionComponent(index: 1,
          inConstraintsString: mediaConstraintFromStore)
    }
  }

  // MARK: -

  //note: converted to computed property again.
  var defaultVideoResolutionMediaConstraint: String {
    get {
      return videoResolutionsStaticValues[0]
    }
  }

  func videoResolutionComponent(index: Int,
                                inConstraintsString constraint: String) -> String? {
    if index != 0 && index != 1 {
      return nil
    }

    let components = constraint.components(separatedBy: "x")
    if components.count != 2 {
      return nil
    }

    return components[index]
  }

  // MARK: - Conversion to RTCMediaConstraints

  /**
   * Converts the current media constraints from the store into a dictionary
   * with RTCMediaConstraints values.
   *
   * - returns: NSDictionary with RTC width and height parameters.
   */
  func currentMediaConstraintFromStoreAsRTCDictionary() -> [String:String]? {
    var mediaConstraintsDictionary: [String:String]? = nil

    let wc = self.currentVideoResolutionWidthFromStore
    let hc = self.currentVideoResolutionHeightFromStore
    if let widthConstraint = wc, let heightConstraint = hc {
      // note: defined in RTCMediaConstraints.h
      // values are "minWidth" and "minHeight", respectively.
      mediaConstraintsDictionary = [
        kRTCMediaConstraintsMinWidth: widthConstraint,
        kRTCMediaConstraintsMinHeight: heightConstraint
      ]
    }

    return mediaConstraintsDictionary
  }

}
